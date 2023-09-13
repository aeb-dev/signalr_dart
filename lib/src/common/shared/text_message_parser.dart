// ignore_for_file: avoid_classes_with_only_static_members

import "dart:typed_data";

import "text_message_formatter.dart";

class TextMessageParser {
  static (
    Uint8List? payload,
    int consumed,
  ) tryParseMessage(
    Uint8List buffer,
  ) {
    int index = buffer.indexOf(TextMessageFormatter.recordSeparator);

    if (index == -1) {
      return (
        null,
        0,
      );
    }

    Uint8List payload = Uint8List.sublistView(buffer, 0, index);

    return (
      payload,
      index + 1,
    );
  }
}
