// ignore_for_file: avoid_classes_with_only_static_members

import "dart:math";
import "dart:typed_data";

class BinaryMessageParser {
  static const int _maxLengthPrefixSize = 5;

  static (
    Uint8List? payload,
    int consumed,
  ) tryParseMessage(Uint8List buffer) {
    {
      if (buffer.isEmpty) {
        return (
          null,
          0,
        );
      }

      // The payload starts with a length prefix encoded as a VarInt. VarInts use the most significant bit
      // as a marker whether the byte is the last byte of the VarInt or if it spans to the next byte. Bytes
      // appear in the reverse order - i.e. the first byte contains the least significant bits of the value
      // Examples:
      // VarInt: 0x35 - %00110101 - the most significant bit is 0 so the value is %x0110101 i.e. 0x35 (53)
      // VarInt: 0x80 0x25 - %10000000 %00101001 - the most significant bit of the first byte is 1 so the
      // remaining bits (%x0000000) are the lowest bits of the value. The most significant bit of the second
      // byte is 0 meaning this is last byte of the VarInt. The actual value bits (%x0101001) need to be
      // prepended to the bits we already read so the values is %01010010000000 i.e. 0x1480 (5248)
      // We support payloads up to 2GB so the biggest number we support is 7fffffff which when encoded as
      // VarInt is 0xFF 0xFF 0xFF 0xFF 0x07 - hence the maximum length prefix is 5 bytes.

      int length = 0;
      int numBytes = 0;

      Uint8List lengthPrefixBuffer = Uint8List.sublistView(
        buffer,
        0,
        min(_maxLengthPrefixSize, buffer.length),
      );

      int byteRead;
      do {
        byteRead = lengthPrefixBuffer[numBytes];
        length = length | ((byteRead & 0x7f) << (numBytes * 7));
        numBytes++;
      } while (
          numBytes < lengthPrefixBuffer.length && ((byteRead & 0x80) != 0));

      // size bytes are missing
      if ((byteRead & 0x80) != 0 && (numBytes < _maxLengthPrefixSize)) {
        return (
          null,
          0,
        );
      }

      if ((byteRead & 0x80) != 0 ||
          (numBytes == _maxLengthPrefixSize && byteRead > 7)) {
        throw const FormatException(
          "Messages over 2GB in size are not supported.",
        );
      }

      // We don't have enough data
      if (buffer.length < length + numBytes) {
        return (
          null,
          0,
        );
      }

      // Get the payload
      Uint8List payload =
          Uint8List.sublistView(buffer, numBytes, numBytes + length);

      return (payload, numBytes + length);
    }
  }
}
