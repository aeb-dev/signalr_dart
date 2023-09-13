part of "invocation_request.dart";

class _Streaming extends InvocationRequest {
  final StreamController<Object?> _streamController =
      StreamController<Object?>();

  Stream<Object?> get result => _streamController.stream;

  _Streaming({
    required super.cancellationToken,
    required super.resultType,
    required super.invocationId,
    required super.hubConnection,
    super.creator,
  }) : super(logger: Logger("Streaming"));

  @override
  Future<void> complete(CompletionMessage message) async {
    _Log.invocationCompleted(logger, invocationId);

    if (message.result != null) {
      _Log.receivedUnexpectedComplete(logger, invocationId);
      _streamController.addError(
        InvalidOperationException(
          "Server provided a result in a completion response to a streamed invocation.",
        ),
      );
    }

    if (message.error != null && message.error!.isNotEmpty) {
      await fail(HubException(message.error));
      return;
    }

    await _streamController.close();
  }

  @override
  Future<void> fail(Exception exception) async {
    _Log.invocationFailed(logger, invocationId);
    _streamController.addError(exception);
    await _streamController.close();
  }

  @override
  Future<bool> streamItem(Object? item) {
    try {
      _streamController.add(item);
    } on Exception catch (ex, st) {
      _Log.errorWritingStreamItem(
        logger,
        invocationId,
        ex,
        st,
      );
    }

    return Future<bool>.value(true);
  }

  @override
  void cancel() {
    if (!_streamController.isClosed) {
      _streamController.addError(
        OperationCancelledException(
          cancellationToken: cancellationToken,
        ),
      );
    }
  }
}
