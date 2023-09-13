import "dart:async";

import "package:async/async.dart";
import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:logging/logging.dart";
import "package:meta/meta.dart";

import "../../../common/signalr/hub_exception.dart";
import "../../../common/signalr/protocol/completion_message.dart";
import "../../../dotnet/invalid_operation_exception.dart";
import "../hub_connection.dart";

part "non_streaming.dart";
part "streaming.dart";
part "invocation_request.log.dart";

abstract class InvocationRequest {
  late final CancellationTokenRegistration _cancellationTokenRegistration;

  @protected
  final Logger logger;

  final Type resultType;
  final CancellationToken cancellationToken;
  final String invocationId;
  final HubConnection hubConnection;

  final Object? Function(dynamic)? creator;

  @protected
  InvocationRequest({
    required this.cancellationToken,
    required this.resultType,
    required this.invocationId,
    required this.logger,
    required this.hubConnection,
    this.creator,
  }) {
    _cancellationTokenRegistration =
        cancellationToken.register<InvocationRequest>(
      callback: (InvocationRequest? self, _) async => self!.cancel(),
      state: this,
    );

    _Log.invocationCreated(logger, invocationId);
  }

  FutureOr<void> fail(Exception exception);
  FutureOr<void> complete(CompletionMessage message);
  Future<bool> streamItem(Object? item);

  @protected
  FutureOr<void> cancel();

  FutureOr<void> dispose() async {
    _Log.invocationDisposed(logger, invocationId);

    // Just in case it hasn't already been completed
    await cancel();

    _cancellationTokenRegistration.dispose();
  }

  static (InvocationRequest request, Future<Object?> result) invoke(
    CancellationToken cancellationToken,
    Type resultType,
    String invocationId,
    HubConnection hubConnection,
    Object? Function(dynamic)? creator,
  ) {
    _NonStreaming req = _NonStreaming(
      cancellationToken: cancellationToken,
      resultType: resultType,
      invocationId: invocationId,
      hubConnection: hubConnection,
      creator: creator,
    );

    return (req, req.result);
  }

  static (InvocationRequest request, Stream<Object?> result) streaming(
    CancellationToken cancellationToken,
    Type resultType,
    String invocationId,
    HubConnection hubConnection,
    Object? Function(dynamic)? creator,
  ) {
    _Streaming req = _Streaming(
      cancellationToken: cancellationToken,
      resultType: resultType,
      invocationId: invocationId,
      hubConnection: hubConnection,
      creator: creator,
    );

    return (req, req.result);
  }
}
