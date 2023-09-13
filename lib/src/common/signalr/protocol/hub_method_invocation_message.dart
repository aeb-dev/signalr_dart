import "hub_invocation_message.dart";

abstract class HubMethodInvocationMessage extends HubInvocationMessage {
  String target;
  List<Object?> arguments;
  List<String>? streamIds;

  HubMethodInvocationMessage(
    super.invocationId,
    this.target,
    this.arguments,
    this.streamIds,
  );
}

class StreamInvocationMessage extends HubMethodInvocationMessage {
  StreamInvocationMessage(
    super.target,
    super.arguments,
    super.invocationId,
    super.streamIds,
  );

  @override
  String toString() {
    String args;
    String streamIds;
    try {
      args = arguments.join(", ");
    } on Exception catch (ex) {
      args = "Error: $ex";
    }

    try {
      streamIds = super.streamIds?.join(", ") ?? "";
    } on Exception catch (ex) {
      streamIds = "Error: $ex";
    }

    return "StreamInvocation {{ {invocationId}: '$invocationId', Target: '$target', arguments: [ $args ], streamIds: [ $streamIds ] }}";
  }
}
