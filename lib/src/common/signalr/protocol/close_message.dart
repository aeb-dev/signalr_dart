// ignore_for_file: avoid_positional_boolean_parameters

import "hub_message.dart";

class CloseMessage extends HubMessage {
  static final CloseMessage empty = CloseMessage(null);

  final String? error;
  final bool allowReconnect;

  CloseMessage(
    this.error, [
    this.allowReconnect = false,
  ]);
}
