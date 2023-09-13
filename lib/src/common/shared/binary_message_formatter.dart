// ignore_for_file: avoid_classes_with_only_static_members

import "dart:typed_data";

import "../../dotnet/i_duplex_pipe.dart";

class BinaryMessageFormatter {
  static void writeLengthPrefixOutput(int length, BufferWriter output) {
    Uint8List lenBuffer = Uint8List(5);

    int lenNumBytes = writeLengthPrefix(length, lenBuffer);

    output.add(lenBuffer.sublist(0, lenNumBytes));
  }

  static int writeLengthPrefix(int length, Uint8List output) {
    // This code writes length prefix of the message as a VarInt. Read the comment in
    // the BinaryMessageParser.TryParseMessage for details.
    int lenNumBytes = 0;
    int length_ = length;
    do {
      int current = output[lenNumBytes];
      current = length_ & 0x7f;
      length_ >>= 7;
      if (length_ > 0) {
        current |= 0x80;
      }
      output[lenNumBytes] = current;
      lenNumBytes++;
    } while (length_ > 0);

    return lenNumBytes;
  }

  static int lengthPrefixLength(int length) {
    int length_ = length;
    int lenNumBytes = 0;
    do {
      length_ >>= 7;
      lenNumBytes++;
    } while (length_ > 0);

    return lenNumBytes;
  }
}
