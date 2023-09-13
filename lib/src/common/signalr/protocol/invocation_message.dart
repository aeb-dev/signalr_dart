import "hub_method_invocation_message.dart";

class InvocationMessage extends HubMethodInvocationMessage {
  InvocationMessage(
    super.invocationId,
    super.target,
    super.arguments,
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

    return "InvocationMessage {{ {invocationId}: '$invocationId', Target: '$target', arguments: [ $args ], streamIds: [ $streamIds ] }}";
  }
}
