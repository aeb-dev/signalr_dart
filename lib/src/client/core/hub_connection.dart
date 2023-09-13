import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:logging/logging.dart";
import "package:meta/meta.dart";
import "package:pool/pool.dart";

import "../../common/shared/message_buffer.dart";
import "../../common/signalr/hub_exception.dart";
import "../../common/signalr/i_invocation_binder.dart";
import "../../common/signalr/protocol/ack_message.dart";
import "../../common/signalr/protocol/cancel_invocation_message.dart";
import "../../common/signalr/protocol/close_message.dart";
import "../../common/signalr/protocol/completion_message.dart";
import "../../common/signalr/protocol/handshake_protocol.dart";
import "../../common/signalr/protocol/handshake_request_message.dart";
import "../../common/signalr/protocol/handshake_response_message.dart";
import "../../common/signalr/protocol/hub_invocation_message.dart";
import "../../common/signalr/protocol/hub_message.dart";
import "../../common/signalr/protocol/hub_method_invocation_message.dart";
import "../../common/signalr/protocol/i_hub_protocol.dart";
import "../../common/signalr/protocol/invocation_binding_failure_message.dart";
import "../../common/signalr/protocol/invocation_message.dart";
import "../../common/signalr/protocol/ping_message.dart";
import "../../common/signalr/protocol/sequence_message.dart";
import "../../common/signalr/protocol/stream_item_message.dart";
import "../../dotnet/connection_context.dart";
import "../../dotnet/i_connection_factory.dart";
import "../../dotnet/i_duplex_pipe.dart";
import "../../dotnet/i_stateful_reconnect_feature.dart";
import "../../dotnet/invalid_operation_exception.dart";
import "hub_connection_options.dart";
import "hub_connection_state.dart";
import "i_retry_policy.dart";
import "internal/invocation_request.dart";
import "internal/serialized_hub_message.dart";
import "retry_context.dart";

part "connection_state.dart";
part "invocation_handler_list.dart";
part "invocation_handler.dart";
part "reconnecting_connection_state.dart";
part "subscription.dart";
part "hub_connection.log.dart";

class HubConnection {
  final Logger _logger = Logger("HubConnection");
  final IHubProtocol _protocol;
  final IConnectionFactory _connectionFactory;
  final IRetryPolicy? _reconnectPolicy;
  final Uri _endPoint;
  final Map<String, InvocationHandlerList> _handlers =
      <String, InvocationHandlerList>{};

  final ReconnectingConnectionState _state =
      ReconnectingConnectionState(Logger("HubConnection"));

  bool _disposed = false;

  FutureOr<void> Function(Exception?)? closed;
  FutureOr<void> Function(Exception?)? reconnecting;
  FutureOr<void> Function(String?)? reconnected;

  Duration tickRate = const Duration(seconds: 1);

  final HubConnectionOptions _options;

  String? get connectionId =>
      _state.currentConnectionStateUnsynchronized?.connection.connectionId;

  HubConnectionState get state => _state.overallState;

  HubConnection(
    IConnectionFactory connectionFactory,
    IHubProtocol protocol,
    Uri endPoint,
    HubConnectionOptions options, {
    IRetryPolicy? reconnectPolicy,
  })  : _connectionFactory = connectionFactory,
        _protocol = protocol,
        _endPoint = endPoint,
        _options = options,
        _reconnectPolicy = reconnectPolicy;

  Future<void> start([
    CancellationToken token = CancellationToken.none,
  ]) async {
    _checkDisposed();
    await _startInner(token);
  }

  Future<void> _startInner([
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    await _state.waitConnectionLock(cancellationToken, "_startInner");
    try {
      bool successful = _state.tryChangeState(
        HubConnectionState.disconnected,
        HubConnectionState.connecting,
      );
      if (!successful) {
        throw InvalidOperationException(
          "The HubConnection cannot be started if it is not in the HubConnectionState.Disconnected state.",
        );
      }

      // The StopCts is canceled at the start of StopAsync should be reset every time the connection finishes stopping.
      // If this token is currently canceled, it means that StartAsync was called while StopAsync was still running.
      if (_state.stopCts.token.isCancellationRequested) {
        throw InvalidOperationException(
          "The HubConnection cannot be started while StopAsync is running.",
        );
      }

      CancellationTokenSource lts =
          CancellationTokenSource.createLinkedTokenSource(
        tokens: <CancellationToken>[
          cancellationToken,
          _state.stopCts.token,
        ],
      );
      await _startCore(lts.token);

      lts.dispose();

      _state.changeState(
        HubConnectionState.connecting,
        HubConnectionState.connected,
      );
    } on Exception catch (_) {
      bool successful = _state.tryChangeState(
        HubConnectionState.connecting,
        HubConnectionState.disconnected,
      );
      if (successful) {
        _state.stopCts = CancellationTokenSource();
      }

      rethrow;
    } finally {
      _state.releaseConnectionLock("_startInner");
    }
  }

  Future<void> stop([
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    _checkDisposed();
    await _stopCore();
  }

  Future<void> dispose() async {
    if (!_disposed) {
      await _stopCore();
    }
  }

  Subscription onResult(
    String methodName,
    List<Type> parameterTypes,
    FutureOr<Object?> Function(List<Object?>, Object?) handler, [
    List<Object? Function(dynamic)?> creators = const <Object? Function(
      dynamic,
    )?>[],
    Object? state,
  ]) {
    _Log.registeringHandler(_logger, methodName);

    _checkDisposed();

    InvocationHandler invocationHandler = InvocationHandler(
      parameterTypes,
      handler,
      creators,
      state,
      hasResult: true,
    );
    InvocationHandlerList? invocationHandlerList = _handlers[methodName];
    if (invocationHandlerList == null) {
      invocationHandlerList = InvocationHandlerList(invocationHandler);
      _handlers[methodName] = invocationHandlerList;
    } else {
      invocationHandlerList.add(methodName, invocationHandler);
    }

    return Subscription(
      invocationHandler,
      invocationHandlerList,
    );
  }

  Subscription on(
    String methodName,
    List<Type> parameterTypes,
    FutureOr<void> Function(List<Object?>, Object?) handler, [
    List<Object? Function(dynamic)?> creators = const <Object? Function(
      dynamic,
    )?>[],
    Object? state,
  ]) {
    _Log.registeringHandler(_logger, methodName);

    _checkDisposed();

    InvocationHandler invocationHandler = InvocationHandler(
      parameterTypes,
      handler,
      creators,
      state,
      hasResult: false,
    );
    InvocationHandlerList? invocationHandlerList = _handlers[methodName];
    if (invocationHandlerList == null) {
      invocationHandlerList = InvocationHandlerList(invocationHandler);
      _handlers[methodName] = invocationHandlerList;
    } else {
      invocationHandlerList.add(methodName, invocationHandler);
    }

    return Subscription(
      invocationHandler,
      invocationHandlerList,
    );
  }

  void remove(String methodName) {
    _checkDisposed();
    _Log.removingHandlers(_logger, methodName);
    _handlers.remove(methodName);
  }

  Stream<Object?> streamCore(
    String methodName,
    Type returnType,
    List<Object?> args, [
    Object? Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async* {
    yield* await _streamAsChannelCoreCore(
      methodName,
      returnType,
      args,
      creator,
      cancellationToken,
    );
  }

  Future<Object?> invokeCore(
    String methodName,
    Type returnType,
    List<Object?> args, [
    Object? Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    Object? result = await _invokeCoreCore(
      methodName,
      returnType,
      args,
      creator: creator,
      cancellationToken: cancellationToken,
    );

    return result;
  }

  Future<void> sendCore(
    String methodName,
    List<Object?> args, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    await _sendCoreCore(
      methodName,
      args,
      cancellationToken,
    );
  }

  Future<void> _startCore([
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    cancellationToken.throwIfCancellationRequested();

    _checkDisposed();

    _Log.starting(_logger);

    // Start the connection
    ConnectionContext connection = await _connectionFactory.connect(
      _endPoint,
      cancellationToken,
    );

    ConnectionState startingConnectionState = ConnectionState(
      connection: connection,
      hubConnection: this,
    );

    // From here on, if an error occurs we need to shut down the connection because
    // we still own it.
    try {
      _Log.hubProtocol(
        _logger,
        _protocol.name,
        _protocol.version,
      );
      await _handshake(
        startingConnectionState,
        cancellationToken,
      );
    } on Exception catch (e, st) {
      _Log.errorStartingConnection(
        _logger,
        e,
        st,
      );

      startingConnectionState.cleanup();

      // Can't have any invocations to cancel, we're in the lock.
      await close(startingConnectionState.connection);
      rethrow;
    }

    // Set this at the end to avoid setting internal state until the connection is real
    _state.currentConnectionStateUnsynchronized = startingConnectionState;
    // // Tell the server we intend to ping.
    // // Old clients never ping, and shouldn't be timed out, so ping to tell the server that we should be timed out if we stop.
    // // StartAsyncCore is invoked and awaited by StartAsyncInner and ReconnectAsync with the connection lock still acquired.
    // if (!(connection.Features.Get<IConnectionInherentKeepAliveFeature>()?.HasInherentKeepAlive ?? false))
    // {
    //     await SendHubMessage(startingConnectionState, PingMessage.Instance, cancellationToken).ConfigureAwait(false);
    // }
    startingConnectionState.receiveTask = _receiveLoop(startingConnectionState);
    _Log.started(_logger);
  }

  Future<void> close(ConnectionContext connection) async {
    await connection.dispose();
  }

  // This method does both Dispose and Start, the 'disposing' flag indicates which.
  // The behaviors are nearly identical, except that the _disposed flag is set in the lock
  // if we're disposing.
  Future<void> _stopCore() async {
    // StartAsync acquires the connection lock for the duration of the handshake.
    // ReconnectAsync also acquires the connection lock for reconnect attempts and handshakes.
    // Cancel the StopCts without acquiring the lock so we can short-circuit it.
    await _state.stopCts.cancel();

    // Potentially wait for StartAsync to finish, and block a new StartAsync from
    // starting until we've finished stopping.
    await _state.waitConnectionLock(CancellationToken.none, "_stopCore");

    if (!_state.isReconnectCompleted) {
      // Let the current reconnect attempts finish if necessary without the lock.
      // Otherwise, ReconnectAsync will stall forever acquiring the lock.
      // It should never throw, even if the reconnect attempts fail.
      // The StopCts should prevent the HubConnection from restarting until it is reset.
      _state.releaseConnectionLock("_stopCore");
      await _state.reconnectTask;
      await _state.waitConnectionLock(CancellationToken.none, "_stopCore");
    }

    ConnectionState? connectionState;
    Future<void> connectionStateStopFuture = Future<void>.value();
    try {
      if (_disposed) {
        // DisposeAsync should be idempotent.
        return;
      }

      _checkDisposed();

      connectionState = _state.currentConnectionStateUnsynchronized;
      if (connectionState != null) {
        connectionState.stopping = true;

        // Try to send CloseMessage
        unawaited(_sendHubMessage(connectionState, CloseMessage.empty));

        if (connectionState.connection.useStatefulReconnect) {
          (connectionState.connection.transport as IStatefulReconnectFeature)
              .disableReconnect();
        }
      } else {
        // Reset StopCts if there isn't an active connection so that the next StartAsync wont immediately fail due to the token being canceled
        _state.stopCts = CancellationTokenSource();
      }

      _disposed = true;

      if (connectionState != null) {
        // Start Stop inside the lock so a closure from the transport side at the same time as this doesn't cause an ODE
        // But don't await the call in the lock as that could deadlock with HandleConnectionClose in the ReceiveLoop
        connectionStateStopFuture = connectionState.stop();
      }
    } finally {
      _state.releaseConnectionLock("_stopCore");
    }

    await connectionStateStopFuture;
  }

  Future<Stream<Object?>> _streamAsChannelCoreCore(
    String methodName,
    Type returnType,
    List<Object?> args, [
    Object? Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    Future<void> onStreamCancelled(InvocationRequest irq) async {
      // We need to take the connection lock in order to ensure we a) have a connection and b) are the only one accessing the write end of the pipe.
      await _state.waitConnectionLock(
        CancellationToken.none,
        "onStreamCancelled",
      );
      try {
        if (_state.currentConnectionStateUnsynchronized != null) {
          _Log.sendingCancellation(
            _logger,
            irq.invocationId,
          );

          // Fire and forget, if it fails that means we aren't connected anymore.
          // Don't pass irq.CancellationToken, that would result in canceling the Flush and a delayed CancelInvocationMessage being sent.
          unawaited(
            _sendHubMessage(
              _state.currentConnectionStateUnsynchronized!,
              CancelInvocationMessage(irq.invocationId),
            ),
          );
        } else {
          _Log.unableToSendCancellation(
            _logger,
            irq.invocationId,
          );
        }
      }
      // ignore: empty_catches, avoid_catches_without_on_clauses
      catch (_) {
        // Connection closed while trying to cancel a stream. This is fine to ignore.
      } finally {
        _state.releaseConnectionLock("onStreamCancelled");
      }

      irq.dispose();
    }

    _checkDisposed();
    ConnectionState connectionState = await _state.waitForActiveConnection(
      "streamAsChannelCore",
      cancellationToken,
    );

    try {
      _checkDisposed();
      cancellationToken.throwIfCancellationRequested();

      var (
        Map<String, Stream<dynamic>>? readers,
        List<Object?> unusedArgs,
        List<String>? streamIds,
      ) = packageStreamingParams(
        connectionState,
        args,
      );

      var (
        InvocationRequest request,
        Stream<Object?> result,
      ) = InvocationRequest.streaming(
        cancellationToken,
        returnType,
        connectionState.getNextId(),
        this,
        creator,
      );

      await _invokeStream(
        connectionState,
        methodName,
        request,
        unusedArgs,
        streamIds,
        cancellationToken,
      );

      if (cancellationToken.canBeCancelled) {
        cancellationToken.register<InvocationRequest>(
          callback: (InvocationRequest? ir, _) async {
            await onStreamCancelled(ir!);
          },
          state: request,
        );
      }

      _launchStreams(
        connectionState,
        readers,
        cancellationToken,
      );

      return result;
    } finally {
      _state.releaseConnectionLock("_streamAsChannelCoreCore");
    }
  }

  (
    Map<String, Stream<dynamic>>? readers,
    List<Object?> unusedArgs,
    List<String>? streamIds,
  ) packageStreamingParams(
    ConnectionState connectionState,
    List<Object?> args,
  ) {
    Map<String, Stream<dynamic>> readers = <String, Stream<dynamic>>{};
    List<String> streamIds = <String>[];
    int newArgsCount = args.length;
    List<bool> isStreaming = List<bool>.filled(args.length, false);

    for (int index = 0; index < args.length; ++index) {
      Object? arg = args[index];
      if (arg != null && arg is Stream) {
        isStreaming[index] = true;
        newArgsCount--;

        String id = connectionState.getNextId();
        readers[id] = arg;
        streamIds.add(id);

        _Log.startingStream(_logger, id);
      }
    }

    if (newArgsCount == args.length) {
      return (null, args, null);
    }

    List<Object?> newArgs;
    if (newArgsCount == 0) {
      newArgs = List<Object?>.empty();
    } else {
      int newArgsIndex = 0;
      newArgs = List<Object?>.filled(
        newArgsCount,
        null,
      );
      for (int index = 0; index < args.length; ++index) {
        if (!isStreaming[index]) {
          newArgs[newArgsIndex] = args[index];
          newArgsIndex++;
        }
      }
    }

    return (readers, newArgs, streamIds);
  }

  void _launchStreams(
    ConnectionState connectionState,
    Map<String, Stream<dynamic>>? readers, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) {
    if (readers == null) {
      // if there were no streaming parameters then readers is never initialized
      return;
    }

    // It's safe to access connectionState.UploadStreamToken as we still have the connection lock
    CancellationTokenSource cts =
        CancellationTokenSource.createLinkedTokenSource(
      tokens: <CancellationToken>[
        connectionState.uploadStreamToken,
        cancellationToken,
      ],
    );

    // For each stream that needs to be sent, run a "send items" task in the background.
    // This reads from the channel, attaches streamId, and sends to server.
    // A single background thread here quickly gets messy.
    for (MapEntry<String, Stream<dynamic>> me in readers.entries) {
      unawaited(
        _sendStreamItems(
          connectionState,
          me.key,
          me.value,
          cts,
        ),
      );
    }
  }

  Future<void> _sendStreamItems(
    ConnectionState connectionState,
    String streamId,
    Stream<Object?> stream,
    CancellationTokenSource tokenSource,
  ) async {
    CancellationToken cancelToken = tokenSource.token;
    Future<void> readChannelStream() async {
      await for (Object? item in stream) {
        if (cancelToken.isCancellationRequested) {
          break;
        }

        await _sendWithLock(
          connectionState,
          StreamItemMessage(
            streamId,
            item,
          ),
          tokenSource.token,
          "_sendStreamItems",
        );

        _Log.sendingStreamItem(_logger, streamId);
      }
    }

    await _commonStreaming(
      connectionState,
      streamId,
      readChannelStream,
    );
  }

  Future<void> _commonStreaming(
    ConnectionState connectionState,
    String streamId,
    Future<void> Function() createAndConsumeStream,
  ) async {
    _Log.startingStream(_logger, streamId);

    String? responseError;
    try {
      await createAndConsumeStream();
    } on OperationCancelledException catch (_) {
      _Log.cancellingStream(_logger, streamId);
      responseError = "Stream canceled by client.";
    } on Exception catch (ex, st) {
      _Log.erroredStream(_logger, streamId, ex, st);
      responseError = "Stream errored by client: '$ex' '$st'";
    }

    // Don't use cancellation token here
    // this is triggered by a cancellation token to tell the server that the client is done streaming
    await _state.waitConnectionLock(CancellationToken.none, "_commonStreaming");
    try {
      // Avoid sending when the connection isn't active, likely happens if there is an active stream when the connection closes
      if (_state.isConnectionActive()) {
        _Log.completingStream(_logger, streamId);
        await _sendHubMessage(
          connectionState,
          CompletionMessage.withError(
            streamId,
            responseError,
          ),
        );
      } else {
        _Log.completingStreamNotSent(_logger, streamId);
      }
    } on Exception catch (ex, st) {
      _Log.errorSendingStreamCompletion(_logger, streamId, ex, st);
    } finally {
      _state.releaseConnectionLock("_commonStreaming");
    }
  }

  Future<Object?> _invokeCoreCore(
    String methodName,
    Type returnType,
    List<Object?> args, {
    Object? Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  }) async {
    _checkDisposed();
    ConnectionState connectionState = await _state.waitForActiveConnection(
      "invokeCore",
      cancellationToken,
    );

    Future<Object?> invocationTask;
    try {
      _checkDisposed();

      var (
        Map<String, Stream<dynamic>>? readers,
        List<Object?> unusedArgs,
        List<String>? streamIds,
      ) = packageStreamingParams(
        connectionState,
        args,
      );

      var (
        InvocationRequest request,
        Future<Object?> result,
      ) = InvocationRequest.invoke(
        cancellationToken,
        returnType,
        connectionState.getNextId(),
        this,
        creator,
      );
      invocationTask = result;
      await _invokeCore(
        connectionState,
        methodName,
        request,
        unusedArgs,
        streamIds,
        cancellationToken,
      );

      _launchStreams(
        connectionState,
        readers,
        cancellationToken,
      );
    } finally {
      _state.releaseConnectionLock("_invokeCoreCore");
    }

    // Wait for this outside the lock, because it won't complete until the server responds
    Object? result = await invocationTask;
    return result;
  }

  Future<void> _invokeCore(
    ConnectionState connectionState,
    String methodName,
    InvocationRequest irq,
    List<Object?> args,
    List<String>? streams,
    CancellationToken cancellationToken,
  ) async {
    _Log.preparingBlockingInvocation(
      _logger,
      irq.invocationId,
      methodName,
      irq.resultType.toString(),
      args.length,
    );

    // Client invocations are always blocking
    InvocationMessage invocationMessage = InvocationMessage(
      irq.invocationId,
      methodName,
      args,
      streams,
    );

    _Log.registeringInvocation(
      _logger,
      irq.invocationId,
    );
    connectionState.addInvocation(irq);

    // Trace the full invocation
    _Log.issuingInvocation(
      _logger,
      irq.invocationId,
      methodName,
      irq.resultType.toString(),
      args,
    );

    try {
      await _sendHubMessage(
        connectionState,
        invocationMessage,
        cancellationToken,
      );
    } on Exception catch (ex, st) {
      _Log.failedToSendInvocation(
        _logger,
        irq.invocationId,
        ex,
        st,
      );
      connectionState.tryRemoveInvocation(irq.invocationId);
      irq.fail(ex);
    }
  }

  Future<void> _invokeStream(
    ConnectionState connectionState,
    String methodName,
    InvocationRequest irq,
    List<Object?> args,
    List<String>? streams,
    CancellationToken cancellationToken,
  ) async {
    _Log.preparingStreamingInvocation(
      _logger,
      irq.invocationId,
      methodName,
      irq.resultType.toString(),
      args.length,
    );

    StreamInvocationMessage invocationMessage = StreamInvocationMessage(
      irq.invocationId,
      methodName,
      args,
      streams,
    );

    _Log.registeringInvocation(
      _logger,
      irq.invocationId,
    );

    connectionState.addInvocation(irq);

    // Trace the full invocation
    _Log.issuingInvocation(
      _logger,
      irq.invocationId,
      irq.resultType.toString(),
      methodName,
      args,
    );

    try {
      await _sendHubMessage(
        connectionState,
        invocationMessage,
        cancellationToken,
      );
    } on Exception catch (ex, st) {
      _Log.failedToSendInvocation(
        _logger,
        irq.invocationId,
        ex,
        st,
      );
      connectionState.tryRemoveInvocation(irq.invocationId);
      irq.fail(ex);
    }
  }

  Future<void> _sendHubMessage(
    ConnectionState connectionState,
    HubMessage hubMessage, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    _Log.sendingMessage(
      _logger,
      hubMessage,
    );

    if (connectionState.usingStatefulReconnect()) {
      await connectionState.write(
        SerializedHubMessage.fromMessage(hubMessage),
        cancellationToken,
      );
    } else {
      _protocol.writeMessage(
        hubMessage,
        connectionState.connection.transport.output,
      );
      // await connectionState.connection.transport.output.flush(cancellationToken);
    }

    _Log.messageSent(
      _logger,
      hubMessage,
    );

    // We've sent a message, so don't ping for a while
    connectionState.resetSendPing();
  }

  Future<void> _sendCoreCore(
    String methodName,
    List<Object?> args,
    CancellationToken cancellationToken,
  ) async {
    _checkDisposed();
    ConnectionState connectionState = await _state.waitForActiveConnection(
      "sendCore",
      cancellationToken,
    );
    try {
      _checkDisposed();

      var (
        Map<String, Stream<dynamic>>? readers,
        List<Object?> unusedArgs,
        List<String>? streamIds,
      ) = packageStreamingParams(
        connectionState,
        args,
      );

      _Log.preparingNonBlockingInvocation(
        _logger,
        methodName,
        args.length,
      );

      InvocationMessage invocationMessage = InvocationMessage(
        null,
        methodName,
        unusedArgs,
        streamIds,
      );
      await _sendHubMessage(
        connectionState,
        invocationMessage,
        cancellationToken,
      );

      _launchStreams(
        connectionState,
        readers,
        cancellationToken,
      );
    } finally {
      _state.releaseConnectionLock("_sendCoreCore");
    }
  }

  Future<void> _sendWithLock(
    ConnectionState expectedConnectionState,
    HubMessage message,
    CancellationToken cancellationToken,
    String callerName,
  ) async {
    _checkDisposed();
    ConnectionState connectionState = await _state.waitForActiveConnection(
      callerName,
      cancellationToken,
    );
    try {
      _checkDisposed();

      await _sendHubMessage(
        connectionState,
        message,
        cancellationToken,
      );
    } finally {
      _state.releaseConnectionLock("_sendWithLock");
    }
  }

  Future<CloseMessage?> _processMessage(
    HubMessage message,
    ConnectionState connectionState,
    StreamSink<InvocationMessage> invocationMessageWriter,
  ) async {
    _Log.resettingKeepAliveTimer(
      _logger,
    );
    connectionState.resetTimeout();

    if (!connectionState.shouldProcessMessage(message)) {
      return null;
    }

    InvocationRequest? irq;
    switch (message) {
      case InvocationBindingFailureMessage bindingFailure:
        // The server can't receive a response, so we just drop the message and log
        // REVIEW: Is this the right approach?
        _Log.argumentBindingFailure(
          _logger,
          bindingFailure.invocationId,
          bindingFailure.target,
          bindingFailure.exception,
          bindingFailure.stackTrace,
        );

        if (bindingFailure.invocationId != null) {
          await _sendWithLock(
            connectionState,
            CompletionMessage.withError(
              bindingFailure.invocationId,
              "Client failed to parse argument(s).",
            ),
            CancellationToken.none,
            "_processMessage",
          );
        }
      case InvocationMessage invocation:
        _Log.receivedInvocation(
          _logger,
          invocation.invocationId,
          invocation.target,
          invocation.arguments,
        );
        invocationMessageWriter.add(invocation);
      case CompletionMessage completion:
        irq = connectionState.tryRemoveInvocation(completion.invocationId!);
        if (irq == null) {
          _Log.droppedCompletionMessage(
            _logger,
            completion.invocationId!,
          );
          break;
        }

        await _dispatchInvocationCompletion(completion, irq);
        await irq.dispose();
      case StreamItemMessage streamItem:
        irq = connectionState.tryGetInvocation(streamItem.invocationId!);
        if (irq == null) {
          _Log.droppedStreamMessage(
            _logger,
            streamItem.invocationId!,
          );
          break;
        }

        await _dispatchInvocationStreamItem(streamItem, irq);
      case CloseMessage close:
        if (close.error == null) {
          _Log.receivedClose(
            _logger,
          );
        } else {
          _Log.receivedCloseWithError(
            _logger,
            close.error!,
          );
        }

        if (connectionState.connection.useStatefulReconnect) {
          (connectionState.connection.transport as IStatefulReconnectFeature)
              .disableReconnect();
        }

        return close;
      case PingMessage _:
        _Log.receivedPing(
          _logger,
        );
      case AckMessage ackMessage:
        _Log.receivedAckMessage(_logger, ackMessage.sequenceId);
        connectionState.ack(ackMessage);
      case SequenceMessage sequenceMessage:
        _Log.receivedSequenceMessage(_logger, sequenceMessage.sequenceId);
        connectionState.resetSequence(sequenceMessage);
      default:
        throw Exception("Unexpected message type: ${message.runtimeType}");
    }

    return null;
  }

  Future<void> _dispatchInvocation(
    InvocationMessage invocation,
    ConnectionState connectionState,
  ) async {
    bool expectsResult =
        invocation.invocationId != null && invocation.invocationId!.isNotEmpty;
    InvocationHandlerList? invocationHandlerList = _handlers[invocation.target];
    if (invocationHandlerList == null) {
      if (expectsResult) {
        _Log.missingResultHandler(
          _logger,
          invocation.target,
        );
        try {
          await _sendWithLock(
            connectionState,
            CompletionMessage.withError(
              invocation.invocationId,
              "Client didn't provide a result.",
            ),
            CancellationToken.none,
            "_dispatchInvocation",
          );
        } on Exception catch (ex, st) {
          _Log.errorSendingInvocationResult(
            _logger,
            invocation.invocationId!,
            invocation.target,
            ex,
            st,
          );
        }
      } else {
        _Log.missingHandler(
          _logger,
          invocation.invocationId!,
        );
      }
      return;
    }

    Object? result;
    Object? resultException;
    bool hasResult = false;
    for (InvocationHandler handler in invocationHandlerList.handlers) {
      try {
        FutureOr<dynamic> task = handler.invoke(invocation.arguments);
        if (handler.hasResult) {
          result = await task;
          hasResult = true;
        } else {
          await task;
        }
      } on Exception catch (ex, st) {
        _Log.errorInvokingClientSideMethod(
          _logger,
          invocation.invocationId!,
          ex,
          st,
        );
        if (handler.hasResult) {
          resultException = ex;
        }
      }
    }

    if (expectsResult) {
      try {
        if (resultException != null) {
          await _sendWithLock(
            connectionState,
            CompletionMessage.withError(
              invocation.invocationId,
              resultException.toString(),
            ),
            CancellationToken.none,
            "_dispatchInvocation",
          );
        } else if (hasResult) {
          await _sendWithLock(
            connectionState,
            CompletionMessage.withResult(
              invocation.invocationId,
              result,
            ),
            CancellationToken.none,
            "_dispatchInvocation",
          );
        } else {
          _Log.missingResultHandler(
            _logger,
            invocation.target,
          );
          await _sendWithLock(
            connectionState,
            CompletionMessage.withError(
              invocation.invocationId,
              "Client didn't provide a result.",
            ),
            CancellationToken.none,
            "_dispatchInvocation",
          );
        }
      } on Exception catch (ex, st) {
        _Log.errorSendingInvocationResult(
          _logger,
          invocation.invocationId!,
          invocation.target,
          ex,
          st,
        );
      }
    } else if (hasResult) {
      _Log.resultNotExpected(
        _logger,
        invocation.target,
      );
    }
  }

  Future<void> _dispatchInvocationStreamItem(
    StreamItemMessage streamItem,
    InvocationRequest irq,
  ) async {
    _Log.receivedStreamItem(
      _logger,
      irq.invocationId,
    );

    if (irq.cancellationToken.isCancellationRequested) {
      _Log.cancellingStreamItem(
        _logger,
        irq.invocationId,
      );
      return;
    }

    bool result = await irq.streamItem(streamItem.item);
    if (!result) {
      _Log.receivedStreamItemAfterClose(
        _logger,
        irq.invocationId,
      );
    }
  }

  Future<void> _dispatchInvocationCompletion(
    CompletionMessage completion,
    InvocationRequest irq,
  ) async {
    _Log.receivedInvocationCompletion(
      _logger,
      irq.invocationId,
    );

    if (irq.cancellationToken.isCancellationRequested) {
      _Log.cancellingInvocationCompletion(
        _logger,
        irq.invocationId,
      );
    } else {
      await irq.complete(completion);
    }
  }

  void _checkDisposed() {
    if (_disposed) {
      throw const ObjectDisposedException();
    }
  }

  Future<void> _handshake(
    ConnectionState startingConnectionState,
    CancellationToken cancellationToken,
  ) async {
    _Log.sendingHubHandshake(
      _logger,
    );

    HandshakeRequestMessage handshakeRequest =
        HandshakeRequestMessage(_protocol.name, _protocol.version);
    HandshakeProtocol.writeRequestMessage(
      handshakeRequest,
      startingConnectionState.connection.transport.output,
    );

    // FlushResult sendHandshakeResult = await startingConnectionState
    //     .connection.transport.output
    //     .flush(CancellationToken.none);

    if (startingConnectionState.connection.transport.output.isCompleted) {
      // The other side disconnected
      SocketException ex = const SocketException(
        "The server disconnected before the handshake could be started.",
      );
      _Log.errorReceivingHandshakeResponse(
        _logger,
        ex,
        StackTrace.current,
      );
      throw ex;
    }

    BufferReader input = startingConnectionState.connection.transport.input;

    CancellationTokenSource handshakeCts = CancellationTokenSource.withDuration(
      duration: _options.handshakeTimeout,
    );

    try {
      CancellationTokenSource linkedTokenSource =
          CancellationTokenSource.createLinkedTokenSource(
        tokens: <CancellationToken>[
          cancellationToken,
          handshakeCts.token,
        ],
      );

      CancellationToken linkedToken = linkedTokenSource.token;
      while (true) {
        ReadResult result = await input.read(linkedToken);
        Uint8List buffer = result.buffer;
        int consumed_ = 0;
        try {
          if (buffer.isNotEmpty) {
            var (
              HandshakeResponseMessage? message,
              int consumed,
            ) = HandshakeProtocol.tryParseResponseMessage(buffer);
            consumed_ = consumed;
            if (message != null) {
              if (message.error != null) {
                _Log.handshakeServerError(
                  _logger,
                  message.error!,
                );
                throw HubException(
                  "Unable to complete handshake with the server due to an error: ${message.error}",
                );
              }

              _Log.handshakeComplete(
                _logger,
              );
              break;
            }
          }

          if (result.isCompleted) {
            // Not enough data, and we won't be getting any more data.
            throw InvalidOperationException(
              "The server disconnected before sending a handshake response",
            );
          }
        } finally {
          input.advanceTo(consumed_);
        }
      }

      linkedTokenSource.dispose();
    } on HubException catch (_) {
      // This was already logged as a HandshakeServerError
      rethrow;
    } on FormatException catch (ex, st) {
      _Log.errorInvalidHandshakeResponse(
        _logger,
        ex,
        st,
      );
      rethrow;
    } on OperationCancelledException catch (ex, st) {
      if (handshakeCts.isCancellationRequested) {
        _Log.errorHandshakeTimedOut(
          _logger,
          _options.handshakeTimeout,
          ex,
          st,
        );
      } else {
        _Log.errorHandshakeCanceled(
          _logger,
          ex,
          st,
        );
      }

      rethrow;
    } on Exception catch (ex, st) {
      _Log.errorReceivingHandshakeResponse(
        _logger,
        ex,
        st,
      );
      rethrow;
    }
  }

  Future<void> _receiveLoop(ConnectionState connectionState) async {
    Future<void> startProcessingInvocationMessages(
      Stream<InvocationMessage> invocationMessageChannelReader,
    ) async {
      await for (InvocationMessage invocationMessage
          in invocationMessageChannelReader) {
        Future<void> invokeTask =
            _dispatchInvocation(invocationMessage, connectionState);
        // If a client result is expected we shouldn't block on user code as that could potentially permanently block the application
        // Even if it doesn't permanently block, it would be better if non-client result handlers could still be called while waiting for a result
        // e.g. chat while waiting for user input for a turn in a game
        if (invocationMessage.invocationId == null ||
            invocationMessage.invocationId!.isEmpty) {
          await invokeTask;
        }
      }
    }

    _Log.receiveLoopStarting(
      _logger,
    );

    // Performs periodic tasks -- here sending pings and checking timeout
    // Disposed with `timer.Stop()` in the finally block below
    Future<void> timerTask = connectionState.timerLoop(tickRate);

    CancellationTokenSource uploadStreamSource = CancellationTokenSource();
    connectionState.uploadStreamToken = uploadStreamSource.token;

    StreamController<InvocationMessage> invocationMessageChannel =
        StreamController<InvocationMessage>();

    // We can't safely wait for this task when closing without introducing deadlock potential when calling StopAsync in a .On method
    connectionState.invocationMessageReceiveTask =
        startProcessingInvocationMessages(invocationMessageChannel.stream);

    BufferReader input = connectionState.connection.transport.input;

    try {
      while (true) {
        ReadResult result = await input.read();
        Uint8List buffer = result.buffer;
        int consumed_ = 0;

        try {
          if (result.isCancelled) {
            break;
          }

          if (buffer.isNotEmpty) {
            _Log.processingMessage(
              _logger,
              buffer.length,
            );

            CloseMessage? closeMessage;
            while (true) {
              Uint8List slice = Uint8List.sublistView(buffer, consumed_);
              if (slice.isEmpty) {
                break;
              }
              var (
                HubMessage? message,
                int consumed,
              ) = _protocol.tryParseMessage(
                slice,
                connectionState,
              );

              consumed_ += consumed;

              if (message == null) {
                break;
              }

              closeMessage = await _processMessage(
                message,
                connectionState,
                invocationMessageChannel.sink,
              );

              if (closeMessage != null) {
                // Closing because we got a close frame, possibly with an error in it.
                if (closeMessage.error != null) {
                  connectionState.closeException = HubException(
                    "The server closed the connection with the following error: ${closeMessage.error}",
                  );
                }

                // Stopping being true indicates the client shouldn't try to reconnect even if automatic reconnects are enabled.
                if (!closeMessage.allowReconnect) {
                  connectionState.stopping = true;
                }

                break;
              }
            }

            // If we're closing stop everything
            if (closeMessage != null) {
              break;
            }
          }

          if (result.isCompleted) {
            if (buffer.isNotEmpty) {
              throw const FormatException(
                "Connection terminated while reading a message.",
              );
            }
            break;
          }
        } finally {
          input.advanceTo(consumed_);
        }
      }
    } on Exception catch (ex, st) {
      _Log.serverDisconnectedWithError(
        _logger,
        ex,
        st,
      );
    } finally {
      await invocationMessageChannel.close();
      connectionState.timerCancel();
      await timerTask;
      await uploadStreamSource.cancel();
      await _handleConnectionClose(connectionState);
    }
  }

  @visibleForTesting
  Future<void> runTimerActions() async {
    // Don't bother acquiring the connection lock. This is only called from tests.
    await _state.currentConnectionStateUnsynchronized!.runTimerActions();
  }

  @visibleForTesting
  void onServerTimeout() {
    // Don't bother acquiring the connection lock. This is only called from tests.
    _state.currentConnectionStateUnsynchronized!.onServerTimeout();
  }

  Future<void> _handleConnectionClose(ConnectionState connectionState) async {
    // Clear the connectionState field
    await _state.waitConnectionLock(
      CancellationToken.none,
      "_handleConnectionClose",
    );
    try {
      _state.currentConnectionStateUnsynchronized = null;

      // Dispose the connection
      await close(connectionState.connection);

      // Cancel any outstanding invocations within the connection lock
      await connectionState
          .cancelOutstandingInvocations(connectionState.closeException);
      connectionState.cleanup();

      if (connectionState.stopping || _reconnectPolicy == null) {
        if (connectionState.closeException != null) {
          _Log.shutdownWithError(
            _logger,
            connectionState.closeException!,
            StackTrace.current,
          );
        } else {
          _Log.shutdownConnection(
            _logger,
          );
        }

        _state.changeState(
          HubConnectionState.connected,
          HubConnectionState.disconnected,
        );
        _completeClose(connectionState.closeException);
      } else {
        _state.reconnectTask = _reconnect(connectionState.closeException);
      }
    } finally {
      _state.releaseConnectionLock("_handleConnectionClose");
    }
  }

  void _completeClose(Exception? closeException) {
    _state.stopCts = CancellationTokenSource();
    _runCloseEvent(closeException);
  }

  void _runCloseEvent(Exception? closeException) {
    Future<void> runClosedEvent() async {
      try {
        _Log.invokingClosedEventHandler(
          _logger,
        );
        await closed!.call(closeException);
      } on Exception catch (ex, st) {
        _Log.errorDuringClosedEvent(
          _logger,
          ex,
          st,
        );
      }
    }

    if (closed != null) {
      unawaited(runClosedEvent());
    }
  }

  Future<void> _reconnect(Exception? closeException) async {
    int previousReconnectAttempts = 0;
    DateTime reconnectStartTime = DateTime.now().toUtc();
    Exception? retryReason = closeException;
    Duration? nextRetryDelay = _getNextRetryDelay(
      previousReconnectAttempts,
      Duration.zero,
      retryReason,
    );

    if (nextRetryDelay == null) {
      _Log.firstReconnectRetryDelayNull(
        _logger,
      );

      _state.changeState(
        HubConnectionState.connected,
        HubConnectionState.disconnected,
      );

      _completeClose(closeException);
      return;
    }

    _state.changeState(
      HubConnectionState.connected,
      HubConnectionState.reconnecting,
    );

    if (closeException != null) {
      _Log.reconnectingWithError(
        _logger,
        closeException,
        StackTrace.current,
      );
    } else {
      _Log.reconnecting(
        _logger,
      );
    }

    _runReconnectingEvent(closeException);

    while (nextRetryDelay != null) {
      _Log.awaitingReconnectRetryDelay(
        _logger,
        previousReconnectAttempts + 1,
        nextRetryDelay,
      );

      try {
        // await Future<void>.delayed(nextRetryDelay, _state.stopCts.token);
        await Future<void>.delayed(nextRetryDelay);
      } on OperationCancelledException catch (ex) {
        _Log.reconnectingStoppedDuringRetryDelay(
          _logger,
        );

        await _state.waitConnectionLock(CancellationToken.none, "_reconnect");
        try {
          _state.changeState(
            HubConnectionState.reconnecting,
            HubConnectionState.disconnected,
          );

          _completeClose(
            _getOperationCancelledException(
              "Connection stopped during reconnect delay. Done reconnecting.",
              ex,
              _state.stopCts.token,
            ),
          );
        } finally {
          _state.releaseConnectionLock("_reconnect");
        }

        return;
      }

      await _state.waitConnectionLock(
        CancellationToken.none,
        "_reconnect",
      );
      try {
        await _startCore(_state.stopCts.token);

        _Log.reconnected(
          _logger,
          previousReconnectAttempts,
          DateTime.now().toUtc().difference(reconnectStartTime),
        );

        _state.changeState(
          HubConnectionState.reconnecting,
          HubConnectionState.connected,
        );

        _runReconnectedEvent();
        return;
      } on Exception catch (ex, st) {
        retryReason = ex;

        _Log.reconnectAttemptFailed(
          _logger,
          ex,
          st,
        );

        if (_state.stopCts.isCancellationRequested) {
          _Log.reconnectingStoppedDuringReconnectAttempt(
            _logger,
          );

          _state.changeState(
            HubConnectionState.reconnecting,
            HubConnectionState.disconnected,
          );

          _completeClose(
            _getOperationCancelledException(
              "Connection stopped during reconnect attempt. Done reconnecting.",
              ex,
              _state.stopCts.token,
            ),
          );
          return;
        }

        previousReconnectAttempts++;
      } finally {
        _state.releaseConnectionLock("_reconnect");
      }

      nextRetryDelay = _getNextRetryDelay(
        previousReconnectAttempts,
        DateTime.now().toUtc().difference(reconnectStartTime),
        retryReason,
      );
    }

    await _state.waitConnectionLock(CancellationToken.none, "_reconnect");
    try {
      Duration elapsedTime =
          DateTime.now().toUtc().difference(reconnectStartTime);
      _Log.reconnectAttemptsExhausted(
        _logger,
        previousReconnectAttempts,
        elapsedTime,
      );

      _state.changeState(
        HubConnectionState.reconnecting,
        HubConnectionState.disconnected,
      );

      _completeClose(
        OperationCancelledException(
          cancellationToken:
              CancellationToken.none, // TODO: this should not be none, fix it
          reason:
              "Reconnect retries have been exhausted after $previousReconnectAttempts failed attempts and $elapsedTime elapsed. Disconnecting.",
        ),
      );
    } finally {
      _state.releaseConnectionLock("_reconnect");
    }
  }

  Duration? _getNextRetryDelay(
    int previousRetryCount,
    Duration elapsedTime,
    Exception? retryReason,
  ) {
    try {
      return _reconnectPolicy!.nextRetryDelay(
        RetryContext(
          previousRetryCount,
          elapsedTime,
          retryReason,
        ),
      );
    } on Exception catch (ex, st) {
      _Log.errorDuringNextRetryDelay(
        _logger,
        ex,
        st,
      );
      return null;
    }
  }

  OperationCancelledException _getOperationCancelledException(
    String message,
    Exception innerException,
    CancellationToken cancellationToken,
  ) =>
      OperationCancelledException(
        cancellationToken: cancellationToken,
        reason: message,
        // innerException: innerException, // TODO: add exceptio maybe?
      );

  void _runReconnectingEvent(Exception? closeException) {
    Future<void> runReconnectingEvent() async {
      try {
        await reconnecting!.call(closeException);
      } on Exception catch (ex, st) {
        _Log.errorDuringReconnectingEvent(
          _logger,
          ex,
          st,
        );
      }
    }

    // There is no need to start a new task if there is no Reconnecting event registered
    if (reconnecting != null) {
      // Fire-and-forget the closed event
      unawaited(runReconnectingEvent());
    }
  }

  void _runReconnectedEvent() {
    Future<void> runReconnectedEvent() async {
      try {
        await reconnected!.call(connectionId);
      } on Exception catch (ex, st) {
        _Log.errorDuringReconnectedEvent(
          _logger,
          ex,
          st,
        );
      }
    }

    // There is no need to start a new task if there is no Reconnected event registered
    if (reconnected != null) {
      // Fire-and-forget the reconnected event
      unawaited(runReconnectedEvent());
    }
  }
}
