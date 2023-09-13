import "hub_message.dart";

class HandshakeRequestMessage extends HubMessage {
  final String protocol;
  final int version;

  HandshakeRequestMessage(
    this.protocol,
    this.version,
  );
}
