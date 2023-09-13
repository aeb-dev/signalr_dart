import "hub_message.dart";

class AckMessage extends HubMessage {
  int sequenceId;

  AckMessage(this.sequenceId);
}
