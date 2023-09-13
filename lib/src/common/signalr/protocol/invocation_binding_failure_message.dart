import "hub_invocation_message.dart";

class InvocationBindingFailureMessage extends HubInvocationMessage {
  final Exception exception;
  final StackTrace stackTrace;
  final String target;

  InvocationBindingFailureMessage(
    super.invocationId,
    this.target,
    this.exception,
    this.stackTrace,
  );
}
