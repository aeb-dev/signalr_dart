part of "hub_connection.dart";

class ConnectionState implements IInvocationBinder {
  final HubConnection _hubConnection;
  final Logger _logger;
  final bool _hasInherentKeepAlive;
  final MessageBuffer? _messageBuffer;

  final Pool _pool = Pool(1);
  final Map<String, InvocationRequest> _pendingCalls =
      <String, InvocationRequest>{};
  Completer<Object?>? _completer;

  bool stopping = false;

  int _nextInvocationId = 0;
  late DateTime _nextActivationServerTimeout;
  late DateTime _nextActivationSendPing;

  ConnectionContext connection;
  Future<void>? receiveTask;
  Exception? closeException;
  CancellationToken uploadStreamToken = CancellationToken.none;

  Future<void>? invocationMessageReceiveTask;

  late Completer<void> _timerTask;

  ConnectionState({
    required this.connection,
    required HubConnection hubConnection,
  })  : _hubConnection = hubConnection,
        _logger = hubConnection._logger,
        _hasInherentKeepAlive = connection.hasInherentKeepAlive,
        _messageBuffer = connection.useStatefulReconnect
            ? MessageBuffer(
                connection,
                hubConnection._protocol,
                hubConnection._options.statefulReconnectBufferSize,
              )
            : null {
    if (connection.useStatefulReconnect &&
        connection.transport is IStatefulReconnectFeature) {
      (connection.transport as IStatefulReconnectFeature)
          .onReconnected(_messageBuffer!.resend);
    }
  }

  String getNextId() => (++_nextInvocationId).toString();

  void addInvocation(InvocationRequest irq) {
    bool hasInvocation = _pendingCalls.containsKey(irq.invocationId);
    if (hasInvocation) {
      _Log.invocationAlreadyInUse(_logger, irq.invocationId);
      throw InvalidOperationException(
        "Invocation ID '${irq.invocationId}' is already in use.",
      );
    } else {
      _pendingCalls[irq.invocationId] = irq;
    }
  }

  InvocationRequest? tryGetInvocation(String invocationId) {
    InvocationRequest? ir = _pendingCalls[invocationId];
    return ir;
  }

  InvocationRequest? tryRemoveInvocation(String invocationId) {
    InvocationRequest? ir = _pendingCalls.remove(invocationId);
    return ir;
  }

  Future<void> cancelOutstandingInvocations(Exception? exception) async {
    _Log.cancellingOutstandingInvocations(_logger);

    PoolResource pr = await _pool.request();

    for (InvocationRequest outstandingCall in _pendingCalls.values) {
      _Log.removingInvocation(_logger, outstandingCall.invocationId);
      if (exception != null) {
        await outstandingCall.fail(exception);
      }

      await outstandingCall.dispose();
    }

    _pendingCalls.clear();

    pr.release();
  }

  Future<void> stop() async {
    PoolResource pr = await _pool.request();
    try {
      if (_completer != null) {
        await _completer!.future;
      } else {
        _completer = Completer<Object?>();
        await _stop();
      }
    } finally {
      pr.release();
    }
  }

  Future<void> _stop() async {
    _Log.stopping(
      _logger,
    );

    _Log.terminatingReceiveLoop(
      _logger,
    );

    connection.transport.input.cancelPendingRead();

    _Log.waitingForReceiveLoopToTerminate(
      _logger,
    );

    await (receiveTask ?? Future<void>.value());

    _Log.stopped(
      _logger,
    );

    _completer!.complete(null);
  }

  void cleanup() {
    _messageBuffer?.dispose();
  }

  Future<void> timerLoop(Duration period) {
    resetTimeout();
    resetSendPing();

    _timerTask = Completer<void>();

    Timer.periodic(
      period,
      (Timer timer) async {
        if (_timerTask.isCompleted) {
          timer.cancel();
          return;
        }
        await runTimerActions();
      },
    );

    return _timerTask.future;
  }

  void timerCancel() {
    _timerTask.complete();
  }

  Future<void> write(
    SerializedHubMessage message,
    CancellationToken cancellationToken,
  ) async {
    await _messageBuffer!.write(
      message,
      cancellationToken,
    );
  }

  bool shouldProcessMessage(HubMessage message) {
    if (usingStatefulReconnect()) {
      if (!_messageBuffer!.shouldProcessMessage(message)) {
        _Log.droppingMessage(
          _logger,
          message.runtimeType.toString(),
          (message as HubInvocationMessage).invocationId,
        );
        return false;
      }
    }

    return true;
  }

  void ack(AckMessage ackMessage) {
    if (usingStatefulReconnect()) {
      _messageBuffer!.ack(ackMessage);
    }
  }

  void resetSequence(SequenceMessage sequenceMessage) {
    if (usingStatefulReconnect()) {
      _messageBuffer!.resetSequence(sequenceMessage);
    }
  }

  bool usingStatefulReconnect() => _messageBuffer != null;

  void resetSendPing() {
    _nextActivationSendPing =
        DateTime.now().toUtc().add(_hubConnection._options.keepAliveInterval);
  }

  void resetTimeout() {
    _nextActivationServerTimeout =
        DateTime.now().toUtc().add(_hubConnection._options.serverTimeout);
  }

  @visibleForTesting
  Future<void> runTimerActions() async {
    if (_hasInherentKeepAlive) {
      return;
    }

    if (DateTime.now().toUtc().isAfter(_nextActivationServerTimeout)) {
      onServerTimeout();
    }

    if (DateTime.now().toUtc().isAfter(_nextActivationSendPing) && !stopping) {
      bool hasLock = await _hubConnection._state.tryAcquireConnectionLock();
      if (!hasLock) {
        _Log.unableToAcquireConnectionLockForPing(
          _logger,
        );
        return;
      }

      _Log.acquiredConnectionLockForPing(
        _logger,
      );

      try {
        if (_hubConnection._state.currentConnectionStateUnsynchronized !=
            null) {
          await _hubConnection._sendHubMessage(this, PingMessage.instance);
        }
        // ignore: avoid_catches_without_on_clauses
      } catch (_) {
        // The exception from send should be seen elsewhere in the client. We'll ignore it here.
      } finally {
        _hubConnection._state.releaseConnectionLock("runTimerActions");
      }
    }
  }

  @visibleForTesting
  void onServerTimeout() {
    closeException = TimeoutException(
      "Server timeout (${_hubConnection._options.serverTimeout.inMilliseconds}ms) elapsed without receing a message from the server.",
    );
    connection.transport.input.cancelPendingRead();
  }

  @override
  Object? Function(dynamic)? getReturnTypeCreator(String invocationId) {
    InvocationRequest? ir = tryGetInvocation(invocationId);
    if (ir == null) {
      _Log.receivedUnexpectedResponse(
        _logger,
        invocationId,
      );
      throw ArgumentError(
        "No invocation with id '$invocationId' could be found.",
      );
    }

    return ir.creator;
  }

  @override
  Type getReturnType(String invocationId) {
    InvocationRequest? ir = tryGetInvocation(invocationId);
    if (ir == null) {
      _Log.receivedUnexpectedResponse(
        _logger,
        invocationId,
      );
      throw ArgumentError(
        "No invocation with id '$invocationId' could be found.",
      );
    }

    return ir.resultType;
  }

  @override
  Type getStreamItemType(String streamId) {
    InvocationRequest? ir = tryGetInvocation(streamId);
    if (ir == null) {
      _Log.receivedUnexpectedResponse(
        _logger,
        streamId,
      );
      throw ArgumentError(
        "No invocation with id '$streamId' could be found.",
      );
    }

    return ir.resultType;
  }

  @override
  List<Type> getParameterTypes(String methodName) {
    InvocationHandlerList? invocationHandlerList =
        _hubConnection._handlers[methodName];
    if (invocationHandlerList == null) {
      _Log.missingHandler(
        _logger,
        methodName,
      );
      return <Type>[];
    }

    List<InvocationHandler> handlers = invocationHandlerList.handlers;
    if (handlers.isEmpty) {
      throw InvalidOperationException(
        "There are no callbacks registered for the method '$methodName'",
      );
    }

    return handlers[0].parameterTypes;
  }

  @override
  List<Object? Function(dynamic)?> getParameterTypesCreator(String methodName) {
    InvocationHandlerList? invocationHandlerList =
        _hubConnection._handlers[methodName];
    if (invocationHandlerList == null) {
      _Log.missingHandler(
        _logger,
        methodName,
      );
      return <Object? Function(dynamic)?>[];
    }

    List<InvocationHandler> handlers = invocationHandlerList.handlers;
    if (handlers.isEmpty) {
      throw InvalidOperationException(
        "There are no callbacks registered for the method '$methodName'",
      );
    }

    return handlers[0].creators;
  }

  @override
  String? getTarget(Uint8List utf8Bytes) => null;
}
