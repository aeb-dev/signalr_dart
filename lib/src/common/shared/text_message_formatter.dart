// ignore_for_file: avoid_classes_with_only_static_members

import "dart:typed_data";

import "../../dotnet/i_duplex_pipe.dart";

class TextMessageFormatter {
  static const int recordSeparator = 0x1e;
  static final Uint8List _separatorBuffer =
      Uint8List.fromList(<int>[recordSeparator]);

  static void writeRecordSeparator(BufferWriter output) {
    output.add(_separatorBuffer);
  }
}
