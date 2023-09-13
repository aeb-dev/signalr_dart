part of "hub_connection.dart";

class ReconnectingConnectionState {
  final Pool _pool = Pool(1);
  PoolResource? _poolResource;
  final Logger _logger;
  ConnectionState? currentConnectionStateUnsynchronized;
  HubConnectionState overallState = HubConnectionState.disconnected;
  CancellationTokenSource stopCts = CancellationTokenSource();

  Completer<void> _reconnectTaskCompleter = Completer<void>()..complete();
  set reconnectTask(Future<void> f) {
    _reconnectTaskCompleter = Completer<void>();

    unawaited(
      f
          .whenComplete(_reconnectTaskCompleter.complete)
          .catchError(_reconnectTaskCompleter.completeError),
    );
  }

  Future<void> get reconnectTask => _reconnectTaskCompleter.future;
  bool get isReconnectCompleted => _reconnectTaskCompleter.isCompleted;

  ReconnectingConnectionState(Logger logger) : _logger = logger;

  void changeState(
    HubConnectionState expectedState,
    HubConnectionState newState,
  ) {
    bool successful = tryChangeState(
      expectedState,
      newState,
    );
    if (!successful) {
      _Log.stateTransitionFailed(
        _logger,
        expectedState,
        newState,
        overallState,
      );

      throw InvalidOperationException(
        "The HubConnection failed to transition from the '$expectedState' state to the '$newState' state because it was actually in the '$overallState' state.",
      );
    }
  }

  bool tryChangeState(
    HubConnectionState expectedState,
    HubConnectionState newState,
  ) {
    _Log.attemptingStateTransition(
      _logger,
      expectedState,
      newState,
    );

    if (overallState != expectedState) {
      return false;
    }

    overallState = newState;
    return true;
  }

  Future<void> waitConnectionLock(
    CancellationToken cancellationToken,
    String memberName,
  ) async {
    _Log.waitingOnConnectionLock(
      _logger,
      memberName,
    );
    _poolResource =
        await _pool.request(); // TODO: how to pass cancellationToken?
  }

  Future<bool> tryAcquireConnectionLock() async {
    if (_poolResource != null) {
      return false;
    }

    _poolResource = await _pool.request();

    return true;
  }

  Future<ConnectionState> waitForActiveConnection(
    String methodName,
    CancellationToken cancellationToken,
  ) async {
    await waitConnectionLock(
      cancellationToken,
      methodName,
    );

    if (!isConnectionActive()) {
      releaseConnectionLock(methodName);
      throw InvalidOperationException(
        "The '$methodName' method cannot be called if the connection is not active",
      );
    }

    return currentConnectionStateUnsynchronized!;
  }

  bool isConnectionActive() =>
      currentConnectionStateUnsynchronized != null &&
      !currentConnectionStateUnsynchronized!.stopping;

  void releaseConnectionLock(String memberName) {
    _Log.releasingConnectionLock(
      _logger,
      memberName,
    );
    if (_poolResource != null) {
      _poolResource!.release();
      _poolResource = null;
    }
  }
}
