// ignore_for_file: avoid_positional_boolean_parameters

import "hub_invocation_message.dart";

class CompletionMessage extends HubInvocationMessage {
  String? error;
  Object? result;
  bool hasResult;

  CompletionMessage(
    super.invocationId,
    this.error,
    this.result,
    this.hasResult,
  ) {
    if (error != null && hasResult) {
      throw ArgumentError(
        "Expected either 'error' or 'result' to be provided, but not both",
      );
    }
  }

  CompletionMessage.withError([
    super.invocationId,
    this.error,
  ]) : hasResult = false;

  CompletionMessage.withResult([super.invocationId, this.result])
      : hasResult = true;

  CompletionMessage.empty([super.invocationId]) : hasResult = true;

  @override
  String toString() {
    String errorStr = error == null ? "<<null>>" : "'$error'";
    String resultField = hasResult ? ", Result: ${result ?? "<<null>>"}" : "";
    return "Completion {{ $invocationId: '$invocationId', Error: $errorStr$resultField }}";
  }
}
