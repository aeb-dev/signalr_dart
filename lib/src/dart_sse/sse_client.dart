import "dart:async";
import "dart:typed_data";

import "package:logging/logging.dart";
import "package:meta/meta.dart";
import "package:typed_data/typed_data.dart";

import "../common/shared/text_message_formatter.dart";

abstract class SseClient {
  @protected
  final Logger logger = Logger("SseClient");

  @protected
  final Uint8Buffer sseFrame = Uint8Buffer();

  StreamSink<List<int>> get sink;

  Stream<List<int>> get stream;

  Future<void> get ready;

  @protected
  void add(List<int> event) {
    sseFrame.addAll(event);
  }

  @protected
  Uint8List? getFrameIfReady() {
    int index = sseFrame.indexOf(TextMessageFormatter.recordSeparator);

    if (index == -1) {
      return null;
    }

    Uint8List data = Uint8List(index + 1)..setRange(0, index + 1, sseFrame);
    sseFrame.clear();

    return data;
  }
}
