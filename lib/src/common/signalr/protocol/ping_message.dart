import "hub_message.dart";

class PingMessage extends HubMessage {
  static final PingMessage instance = PingMessage._();

  PingMessage._();
}
