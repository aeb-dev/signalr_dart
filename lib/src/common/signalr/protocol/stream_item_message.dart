import "hub_invocation_message.dart";

class StreamItemMessage extends HubInvocationMessage {
  Object? item;

  StreamItemMessage(super.invocationId, this.item);

  @override
  String toString() =>
      "StreamItem {{ InvocationId: '$invocationId', Item: ${item ?? "<<null>>"} }}";
}
