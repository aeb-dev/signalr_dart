import "hub_message.dart";

class StreamBindingFailureMessage extends HubMessage {
  final String id;
  final Exception exception;
  final StackTrace stackTrace;

  StreamBindingFailureMessage(
    this.id,
    this.exception,
    this.stackTrace,
  );
}
