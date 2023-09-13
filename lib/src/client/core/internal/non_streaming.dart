part of "invocation_request.dart";

class _NonStreaming extends InvocationRequest {
  final CancelableCompleter<Object?> _completer =
      CancelableCompleter<Object?>();
  Future<Object?> get result => _completer.operation.valueOrCancellation();

  _NonStreaming({
    required super.cancellationToken,
    required super.resultType,
    required super.invocationId,
    required super.hubConnection,
    super.creator,
  }) : super(logger: Logger("NonStreaming"));

  @override
  void complete(CompletionMessage message) {
    if (message.error != null && message.error!.isNotEmpty) {
      fail(HubException(message.error));
      return;
    }

    _Log.invocationCompleted(logger, invocationId);
    _completer.complete(message.result);
  }

  @override
  void fail(Exception exception) {
    _Log.invocationFailed(logger, invocationId);
    _completer.completeError(exception);
  }

  @override
  Future<bool> streamItem(Object? item) {
    _Log.streamItemOnNonStreamInvocation(logger, invocationId);
    _completer.completeError(
      Exception(
        "Streaming hub methods must be invoked with the 'HubConnection.HubConnectionExtensions.StreamAsChannelAsync' method.",
      ),
    );
    return Future<bool>.value(true);
  }

  @override
  FutureOr<void> cancel() async {
    await _completer.operation.cancel();
  }
}
