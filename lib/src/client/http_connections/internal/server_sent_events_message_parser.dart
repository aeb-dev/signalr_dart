import "dart:typed_data";

import "../../../extensions/platform.dart";

class ServerSentEventsMessageParser {
  static final int _byteCR = "\r".codeUnitAt(0);
  static final int _byteLF = "\n".codeUnitAt(0);
  static final int _byteColon = ":".codeUnitAt(0);

  static final List<int> _dataPrefix = "data: ".codeUnits;
  static final List<int> _sseLineEnding = "\r\n".codeUnits;

  static final List<int> _newLine = PlatformExtensions.lineSeparator.codeUnits;

  _InternalParseState _internalParserState =
      _InternalParseState.readMessagePayload;
  final List<Uint8List> _data = List<Uint8List>.empty(growable: true);

  (
    ParseResult parseResult,
    Uint8List? message,
    int consumed,
  ) parseMessage(
    Uint8List buffer,
  ) {
    int consumed = 0;
    while (buffer.isNotEmpty) {
      int lineEnd = buffer.indexOf(_byteLF, consumed);
      if (lineEnd == -1) {
        // For the case of data: Foo\r\n\r\<Anything except \n>
        if (_internalParserState == _InternalParseState.readEndOfMessage) {
          if (buffer.length > 1) {
            throw const FormatException(r"Expected a \r\n frame ending");
          }
        }

        // Partial message. We need to read more.
        return (ParseResult.incomplete, null, consumed);
      }

      lineEnd += 1;
      Uint8List line = Uint8List.sublistView(buffer, consumed, lineEnd);

      if (line.length <= 1) {
        throw const FormatException("There was an error in the frame format");
      }

      // Skip comments
      if (line[0] == _byteColon) {
        consumed = lineEnd;
        continue;
      }

      if (_isMessageEnd(line)) {
        _internalParserState = _InternalParseState.readEndOfMessage;
      }
      // To ensure that the \n was preceded by a \r
      // since messages can't contain \n.
      // data: foo\n\bar should be encoded as
      // data: foo\r\n
      // data: bar\r\n
      else if (line[line.length - _sseLineEnding.length] != _byteCR) {
        throw const FormatException(
          r"Unexpected '\n' in message. A '\n' character can only be used as part of the newline sequence '\r\n'",
        );
      } else {
        _ensureStartsWithDataPrefix(line);
      }

      late Uint8List payload;
      switch (_internalParserState) {
        case _InternalParseState.readMessagePayload:
          _ensureStartsWithDataPrefix(line);

          // Slice away the 'data: '
          int payloadLength =
              line.length - (_dataPrefix.length + _sseLineEnding.length);
          Uint8List newData = line.sublist(
            _dataPrefix.length,
            _dataPrefix.length + payloadLength,
          );
          _data.add(newData);

          consumed = lineEnd;
        case _InternalParseState.readEndOfMessage:
          if (_data.length == 1) {
            payload = _data[0];
          } else if (_data.length > 1) {
            // Find the final size of the payload
            int payloadSize = 0;
            for (List<int> dataLine in _data) {
              payloadSize += dataLine.length;
            }

            payloadSize += _newLine.length * _data.length;

            // Allocate space in the payload buffer for the data and the new lines.
            // Subtract newLine length because we don't want a trailing newline.
            payload = Uint8List(payloadSize - _newLine.length);

            int offset = 0;
            for (List<int> dataLine in _data) {
              payload.setAll(offset, dataLine);
              offset += dataLine.length;
              if (offset < payload.length) {
                payload.setAll(offset, _newLine);
                offset += _newLine.length;
              }
            }
          }

          consumed = lineEnd;

          return (ParseResult.completed, payload, consumed);
      }

      if (buffer.length > consumed && buffer[consumed] == _byteCR) {
        _internalParserState = _InternalParseState.readEndOfMessage;
      }
    }

    return (ParseResult.incomplete, null, consumed);
  }

  void reset() {
    _internalParserState = _InternalParseState.readMessagePayload;
    _data.clear();
  }

  void _ensureStartsWithDataPrefix(Uint8List line) {
    if (!(_dataPrefix[0] == line[0] &&
        _dataPrefix[1] == line[1] &&
        _dataPrefix[2] == line[2] &&
        _dataPrefix[3] == line[3] &&
        _dataPrefix[4] == line[4] &&
        _dataPrefix[5] == line[5])) {
      throw const FormatException("Expected the message prefix 'data: '");
    }
  }

  bool _isMessageEnd(Uint8List line) =>
      line.length == _sseLineEnding.length &&
      _sseLineEnding[0] == line[0] &&
      _sseLineEnding[1] == line[1];
}

enum ParseResult {
  completed,
  incomplete,
}

enum _InternalParseState {
  readMessagePayload,
  readEndOfMessage,
  // error,
}
