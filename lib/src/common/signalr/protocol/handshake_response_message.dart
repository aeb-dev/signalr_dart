import "hub_message.dart";

class HandshakeResponseMessage extends HubMessage {
  static final HandshakeResponseMessage empty = HandshakeResponseMessage(null);

  String? error;

  HandshakeResponseMessage(this.error);
}
