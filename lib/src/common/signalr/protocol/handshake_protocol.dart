// ignore_for_file: avoid_classes_with_only_static_members

import "dart:convert";
import "dart:typed_data";

import "package:jsontool/jsontool.dart";
import "package:typed_data/typed_data.dart";

import "../../../dotnet/i_duplex_pipe.dart";
import "../../shared/text_message_formatter.dart";
import "../../shared/text_message_parser.dart";
import "handshake_request_message.dart";
import "handshake_response_message.dart";

class HandshakeProtocol {
  static const String _protocolPropertyName = "protocol";

  static const String _protocolVersionPropertyName = "version";

  static const String _errorPropertyName = "error";

  static const String _typePropertyName = "type";

  static final Uint8List successHandshakeData = _getSuccessHandshakeData();

  static Uint8List _getSuccessHandshakeData() {
    Uint8Buffer buffer = Uint8Buffer();

    ByteConversionSink memoryBufferWriter =
        ByteConversionSink.withCallback(buffer.addAll);

    BufferWriter bufferWriter = BufferWriter(memoryBufferWriter);
    writeResponseMessage(HandshakeResponseMessage.empty, bufferWriter);
    memoryBufferWriter.close();
    return buffer.buffer.asUint8List();
  }

  static void writeRequestMessage(
    HandshakeRequestMessage requestMessage,
    BufferWriter output,
  ) {
    jsonByteWriter(output.sink)
      ..startObject()
      ..addKey(_protocolPropertyName)
      ..addString(requestMessage.protocol)
      ..addKey(_protocolVersionPropertyName)
      ..addNumber(requestMessage.version)
      ..endObject();

    TextMessageFormatter.writeRecordSeparator(output);
  }

  static void writeResponseMessage(
    HandshakeResponseMessage responseMessage,
    BufferWriter output,
  ) {
    JsonWriter<List<int>> writer = jsonByteWriter(output.sink)..startObject();
    if (responseMessage.error != null && responseMessage.error!.isNotEmpty) {
      writer
        ..addKey(_errorPropertyName)
        ..addString(responseMessage.error!);
    }
    writer.endObject();

    TextMessageFormatter.writeRecordSeparator(output);
  }

  static (
    HandshakeResponseMessage? message,
    int consumed,
  ) tryParseResponseMessage(
    Uint8List buffer,
  ) {
    var (
      Uint8List? payload,
      int consumed,
    ) = TextMessageParser.tryParseMessage(buffer);
    if (payload == null) {
      return (null, consumed);
    }

    JsonReader<Uint8List> reader = JsonReader.fromUtf8(payload)..expectObject();

    String? error;

    while (true) {
      String? key = reader.nextKey();
      if (key == null) {
        break;
      }

      switch (key) {
        case _typePropertyName:
          throw const FormatException(
            "Expected a handshake response from the server.",
          );
        case _errorPropertyName:
          error = reader.expectString();
        default:
          reader.skipObjectEntry();
      }
    }

    return (HandshakeResponseMessage(error), consumed);
  }

  (
    HandshakeRequestMessage? message,
    int consumed,
  ) tryParseRequestMessage(Uint8List buffer) {
    var (
      Uint8List? payload,
      int consumed,
    ) = TextMessageParser.tryParseMessage(buffer);
    if (payload == null) {
      return (
        null,
        consumed,
      );
    }

    JsonReader<Uint8List> reader = JsonReader.fromUtf8(payload)..expectObject();

    validateJsonReader(reader);

    String? protocol;
    int? protocolVersion;

    while (true) {
      String? key = reader.nextKey();
      if (key == null) {
        break;
      }

      switch (key) {
        case _protocolPropertyName:
          protocol = reader.expectString();
        case _protocolVersionPropertyName:
          protocolVersion = reader.expectInt();
        default:
          reader.skipObjectEntry();
      }
    }

    if (protocol == null) {
      throw FormatException(
        "Missing required property '$_protocolPropertyName'. Message content: ${utf8.decode(payload)}",
      );
    }
    if (protocolVersion == null) {
      throw FormatException(
        "Missing required property '$_protocolVersionPropertyName'. Message content: ${utf8.decode(payload)}",
      );
    }

    return (
      HandshakeRequestMessage(protocol, protocolVersion),
      consumed,
    );
  }
}
