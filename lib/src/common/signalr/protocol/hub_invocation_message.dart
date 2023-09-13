import "hub_message.dart";

abstract class HubInvocationMessage extends HubMessage {
  Map<String, String> headers = <String, String>{};
  String? invocationId;

  HubInvocationMessage(
    this.invocationId,
  );
}
