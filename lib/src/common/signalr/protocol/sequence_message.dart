import "hub_message.dart";

class SequenceMessage extends HubMessage {
  int sequenceId;

  SequenceMessage(this.sequenceId);
}
