import "dart:typed_data";

import "package:meta/meta.dart";
import "package:msg_pck/msg_pck.dart";

import "../../../../dotnet/i_duplex_pipe.dart";
import "../../../shared/binary_message_formatter.dart";
import "../../../shared/binary_message_parser.dart";
import "../../../shared/try_get_return_type.dart";
import "../../../signalr/i_invocation_binder.dart";
import "../../../signalr/protocol/ack_message.dart";
import "../../../signalr/protocol/cancel_invocation_message.dart";
import "../../../signalr/protocol/close_message.dart";
import "../../../signalr/protocol/completion_message.dart";
import "../../../signalr/protocol/hub_invocation_message.dart";
import "../../../signalr/protocol/hub_message.dart";
import "../../../signalr/protocol/hub_method_invocation_message.dart";
import "../../../signalr/protocol/hub_protocol_constant.dart";
import "../../../signalr/protocol/invocation_binding_failure_message.dart";
import "../../../signalr/protocol/invocation_message.dart";
import "../../../signalr/protocol/ping_message.dart";
import "../../../signalr/protocol/raw_result.dart";
import "../../../signalr/protocol/sequence_message.dart";
import "../../../signalr/protocol/stream_binding_failure_message.dart";
import "../../../signalr/protocol/stream_item_message.dart";

abstract class MessagePackHubProtocolWorker {
  static const int _errorResult = 1;
  static const int _voidResult = 2;
  static const int _nonVoidResult = 3;

  @protected
  Object? deserializeObject(
    MessagePackReader reader,
    Type type,
    Object? Function(dynamic)? creator,
    String field,
  );

  @protected
  void serialize(MessagePackWriter writer, Type type, dynamic value);

  (
    HubMessage? message,
    int consumed,
  ) tryParseMessage(
    Uint8List buffer,
    IInvocationBinder binder,
  ) {
    var (
      List<int>? payload,
      int consumed,
    ) = BinaryMessageParser.tryParseMessage(buffer);
    if (payload == null) {
      return (
        null,
        consumed,
      );
    }

    MessagePackReader reader = MessagePackReader.fromList(payload);
    HubMessage? result = _parseMessage(reader, binder);
    return (
      result,
      consumed,
    );
  }

  HubMessage? _parseMessage(
    MessagePackReader reader,
    IInvocationBinder binder,
  ) {
    int itemCount = reader.readArrayHeader();

    int? messageType = _readInt(reader, "messageType");

    switch (messageType) {
      case HubProtocolConstants.invocationMessageType:
        return _createInvocationMessage(reader, binder, itemCount);
      case HubProtocolConstants.streamInvocationMessageType:
        return _createStreamInvocationMessage(reader, binder, itemCount);
      case HubProtocolConstants.streamItemMessageType:
        return _createStreamItemMessage(reader, binder);
      case HubProtocolConstants.completionMessageType:
        return _createCompletionMessage(reader, binder);
      case HubProtocolConstants.cancelInvocationMessageType:
        return _createCancelInvocationMessage(reader);
      case HubProtocolConstants.pingMessageType:
        return PingMessage.instance;
      case HubProtocolConstants.closeMessageType:
        return _createCloseMessage(reader, itemCount);
      case HubProtocolConstants.ackMessageType:
        return _createAckMessage(reader);
      case HubProtocolConstants.sequenceMessageType:
        return _createSequenceMessage(reader);
      default:
        // Future protocol changes can add message types, old clients can ignore them
        return null;
    }
  }

  HubMessage _createInvocationMessage(
    MessagePackReader reader,
    IInvocationBinder binder,
    int itemCount,
  ) {
    Map<String, String>? headers = _readHeaders(reader);
    String? invocationId = _readInvocationId(reader);

    // For MsgPack, we represent an empty invocation ID as an empty string,
    // so we need to normalize that to "null", which is what indicates a non-blocking invocation.
    if (invocationId == null || invocationId.isEmpty) {
      invocationId = null;
    }

    String? target = _readString(reader, "target");

    List<Object?>? arguments;
    try {
      List<Type> parameterTypes = binder.getParameterTypes(target!);
      List<Object? Function(dynamic)?> creators =
          binder.getParameterTypesCreator(target);
      arguments = _bindArguments(reader, parameterTypes, creators);
    } on Exception catch (ex, st) {
      return InvocationBindingFailureMessage(
        invocationId,
        target!,
        ex,
        st,
      );
    }

    List<String>? streams;
    // Previous clients will send 5 items, so we check if they sent a stream array or not
    if (itemCount > 5) {
      streams = _readStreamIds(reader);
    }

    return _applyHeaders(
      headers,
      InvocationMessage(invocationId, target, arguments, streams),
    );
  }

  HubMessage _createStreamInvocationMessage(
    MessagePackReader reader,
    IInvocationBinder binder,
    int itemCount,
  ) {
    Map<String, String>? headers = _readHeaders(reader);
    String? invocationId = _readInvocationId(reader);
    String? target = _readString(reader, "target");

    List<Object?> arguments;
    try {
      List<Type> parameterTypes = binder.getParameterTypes(target!);
      List<Object? Function(dynamic)?> creators =
          binder.getParameterTypesCreator(target);
      arguments = _bindArguments(reader, parameterTypes, creators);
    } on Exception catch (ex, st) {
      return InvocationBindingFailureMessage(invocationId, target!, ex, st);
    }

    List<String>? streams;
    // Previous clients will send 5 items, so we check if they sent a stream array or not
    if (itemCount > 5) {
      streams = _readStreamIds(reader);
    }

    return _applyHeaders(
      headers,
      StreamInvocationMessage(invocationId, target, arguments, streams),
    );
  }

  HubMessage _createStreamItemMessage(
    MessagePackReader reader,
    IInvocationBinder binder,
  ) {
    Map<String, String>? headers = _readHeaders(reader);
    String? invocationId = _readInvocationId(reader);
    Object? value;
    try {
      Type itemType = binder.getStreamItemType(invocationId!);
      Object? Function(dynamic)? creator =
          binder.getReturnTypeCreator(invocationId);
      value = deserializeObject(reader, itemType, creator, "item");
    } on Exception catch (ex, st) {
      return StreamBindingFailureMessage(invocationId!, ex, st);
    }

    return _applyHeaders(headers, StreamItemMessage(invocationId, value));
  }

  CompletionMessage _createCompletionMessage(
    MessagePackReader reader,
    IInvocationBinder binder,
  ) {
    Map<String, String>? headers = _readHeaders(reader);
    String? invocationId = _readInvocationId(reader);
    int? resultKind = _readInt(reader, "resultKind");

    String? error;
    Object? result;
    bool hasResult = false;

    switch (resultKind) {
      case _errorResult:
        error = _readString(reader, "error");
      case _nonVoidResult:
        hasResult = true;
        Type? itemType = ProtocolHelper.tryGetReturnType(binder, invocationId!);
        if (itemType == null) {
          reader.skip();
        } else {
          if (itemType == RawResult) {
            result = RawResult(reader.readRaw());
          } else {
            try {
              Object? Function(dynamic)? creator =
                  binder.getReturnTypeCreator(invocationId);
              result = deserializeObject(reader, itemType, creator, "argument");
            } on Exception catch (ex) {
              error = "Error trying to deserialize result to $itemType. $ex";
              hasResult = false;
            }
          }
        }
      case _voidResult:
        hasResult = false;
      default:
        throw const FormatException("Invalid invocation result kind.");
    }

    return _applyHeaders(
      headers,
      CompletionMessage(invocationId, error, result, hasResult),
    );
  }

  static CancelInvocationMessage _createCancelInvocationMessage(
    MessagePackReader reader,
  ) {
    Map<String, String>? headers = _readHeaders(reader);
    String invocationId = _readInvocationId(reader)!;
    return _applyHeaders(headers, CancelInvocationMessage(invocationId));
  }

  static CloseMessage _createCloseMessage(
    MessagePackReader reader,
    int itemCount,
  ) {
    String? error = _readString(reader, "error");
    bool allowReconnect = false;

    if (itemCount > 2) {
      allowReconnect = _readBoolean(reader, "allowReconnect")!;
    }

    // An empty string is still an error
    if (error == null && !allowReconnect) {
      return CloseMessage.empty;
    }

    return CloseMessage(error, allowReconnect);
  }

  static Map<String, String>? _readHeaders(MessagePackReader reader) {
    int headerCount = _readMapLength(reader, "headers");
    if (headerCount > 0) {
      Map<String, String> headers = <String, String>{};

      for (int i = 0; i < headerCount; i++) {
        String key = _readString(reader, "headers[$i].Key")!;
        String value = _readString(reader, "headers[$i].Value")!;
        headers[key] = value;
      }
      return headers;
    } else {
      return null;
    }
  }

  static List<String>? _readStreamIds(MessagePackReader reader) {
    int streamIdCount = _readArrayLength(reader, "streamIds");
    List<String>? streams;

    if (streamIdCount > 0) {
      streams = List<String>.empty(growable: true);
      for (int i = 0; i < streamIdCount; i++) {
        streams.add(reader.readString()!);
      }
    }

    return streams;
  }

  static AckMessage _createAckMessage(MessagePackReader reader) =>
      AckMessage(_readInt(reader, "sequenceId"));

  static SequenceMessage _createSequenceMessage(MessagePackReader reader) =>
      SequenceMessage(_readInt(reader, "sequenceId"));

  List<Object?> _bindArguments(
    MessagePackReader reader,
    List<Type> parameterTypes,
    List<Object? Function(dynamic)?> creators,
  ) {
    int argumentCount = _readArrayLength(reader, "arguments");

    if (parameterTypes.length != argumentCount) {
      throw FormatException(
        "Invocation provides $argumentCount argument(s) but target expects ${parameterTypes.length}.",
      );
    }

    try {
      List<Object?> arguments = List<Object?>.filled(argumentCount, null);
      for (int index = 0; index < argumentCount; ++index) {
        arguments[index] = deserializeObject(
          reader,
          parameterTypes[index],
          creators[index],
          "argument",
        );
      }

      return arguments;
    } on Exception {
      throw const FormatException(
        "Error binding arguments. Make sure that the types of the provided values match the types of the hub method being invoked.",
      );
    }
  }

  static T _applyHeaders<T extends HubInvocationMessage>(
    Map<String, String>? source,
    T destination,
  ) {
    if (source != null && source.isNotEmpty) {
      destination.headers = source;
    }

    return destination;
  }

  void writeMessage(HubMessage message, BufferWriter output) {
    MessagePackWriter writer = MessagePackWriter();

    // Write message to a buffer so we can get its length
    _writeMessageCore(message, writer);

    Uint8List data = writer.takeBytes();

    // Write length then message to output
    BinaryMessageFormatter.writeLengthPrefixOutput(data.length, output);

    output.add(data);
  }

  Uint8List getMessageBytes(HubMessage message) {
    MessagePackWriter writer = MessagePackWriter();

    // Write message to a buffer so we can get its length
    _writeMessageCore(message, writer);

    Uint8List data = writer.takeBytes();
    int dataLength = data.length;
    int prefixLength = BinaryMessageFormatter.lengthPrefixLength(dataLength);

    int bufferLength = dataLength + prefixLength;
    Uint8List buffer = Uint8List(dataLength + prefixLength);

    // Write length then message to output
    int written = BinaryMessageFormatter.writeLengthPrefix(dataLength, buffer);
    assert(written == prefixLength, "'written' is not equal to 'prefixLength'");
    buffer.setRange(written, bufferLength, data);

    return buffer;
  }

  void _writeMessageCore(HubMessage message, MessagePackWriter writer) {
    switch (message) {
      case InvocationMessage invocationMessage:
        _writeInvocationMessage(invocationMessage, writer);
      case StreamInvocationMessage streamInvocationMessage:
        _writeStreamInvocationMessage(streamInvocationMessage, writer);
      case StreamItemMessage streamItemMessage:
        _writeStreamingItemMessage(streamItemMessage, writer);
      case CompletionMessage completionMessage:
        _writeCompletionMessage(completionMessage, writer);
      case CancelInvocationMessage cancelInvocationMessage:
        _writeCancelInvocationMessage(cancelInvocationMessage, writer);
      case PingMessage _:
        _writePingMessage(writer);
      case CloseMessage closeMessage:
        _writeCloseMessage(closeMessage, writer);
      case AckMessage ackMessage:
        _writeAckMessage(ackMessage, writer);
      case SequenceMessage sequenceMessage:
        _writeSequenceMessage(sequenceMessage, writer);
      default:
        throw FormatException(
          "Unexpected message type: ${message.runtimeType}",
        );
    }
  }

  void _writeInvocationMessage(
    InvocationMessage message,
    MessagePackWriter writer,
  ) {
    writer
      ..writeArrayHeader(6)
      ..writeInt(HubProtocolConstants.invocationMessageType);

    _packHeaders(message.headers, writer);

    if (message.invocationId == null || message.invocationId!.isEmpty) {
      writer.writeNil();
    } else {
      writer.writeString(message.invocationId);
    }
    writer.writeString(message.target);

    if (message.arguments.isEmpty) {
      writer.writeArrayHeader(0);
    } else {
      writer.writeArrayHeader(message.arguments.length);
      for (Object? arg in message.arguments) {
        _writeArgument(arg, writer);
      }
    }

    _writeStreamIds(message.streamIds, writer);
  }

  void _writeStreamInvocationMessage(
    StreamInvocationMessage message,
    MessagePackWriter writer,
  ) {
    writer
      ..writeArrayHeader(6)
      ..writeInt(HubProtocolConstants.streamInvocationMessageType);

    _packHeaders(message.headers, writer);

    writer
      ..writeString(message.invocationId)
      ..writeString(message.target);

    if (message.arguments.isEmpty) {
      writer.writeArrayHeader(0);
    } else {
      writer.writeArrayHeader(message.arguments.length);
      for (Object? arg in message.arguments) {
        _writeArgument(arg, writer);
      }
    }

    _writeStreamIds(message.streamIds, writer);
  }

  void _writeStreamingItemMessage(
    StreamItemMessage message,
    MessagePackWriter writer,
  ) {
    writer
      ..writeArrayHeader(4)
      ..writeInt(HubProtocolConstants.streamItemMessageType);
    _packHeaders(message.headers, writer);

    writer.writeString(message.invocationId);

    _writeArgument(message.item, writer);
  }

  void _writeArgument(Object? argument, MessagePackWriter writer) {
    if (argument == null) {
      writer.writeNil();
    } else if (argument is RawResult) {
      writer.writeRaw(argument.rawSerializedData);
    } else {
      serialize(writer, argument.runtimeType, argument);
    }
  }

  static void _writeStreamIds(
    List<String>? streamIds,
    MessagePackWriter writer,
  ) {
    if (streamIds != null) {
      writer.writeArrayHeader(streamIds.length);
      for (String streamId in streamIds) {
        writer.writeString(streamId);
      }
    } else {
      writer.writeArrayHeader(0);
    }
  }

  void _writeCompletionMessage(
    CompletionMessage message,
    MessagePackWriter writer,
  ) {
    int resultKind = message.error != null
        ? _errorResult
        : message.hasResult
            ? _nonVoidResult
            : _voidResult;

    writer
      ..writeArrayHeader(4 + (resultKind != _voidResult ? 1 : 0))
      ..writeInt(HubProtocolConstants.completionMessageType);

    _packHeaders(message.headers, writer);

    writer
      ..writeString(message.invocationId)
      ..writeInt(resultKind);

    switch (resultKind) {
      case _errorResult:
        writer.writeString(message.error);
      case _nonVoidResult:
        _writeArgument(message.result, writer);
    }
  }

  static void _writeCancelInvocationMessage(
    CancelInvocationMessage message,
    MessagePackWriter writer,
  ) {
    writer
      ..writeArrayHeader(3)
      ..writeInt(HubProtocolConstants.cancelInvocationMessageType);
    _packHeaders(message.headers, writer);
    writer.writeString(message.invocationId);
  }

  static void _writeCloseMessage(
    CloseMessage message,
    MessagePackWriter writer,
  ) {
    writer
      ..writeArrayHeader(3)
      ..writeInt(HubProtocolConstants.closeMessageType);
    if (message.error == null || message.error!.isEmpty) {
      writer.writeNil();
    } else {
      writer.writeString(message.error);
    }

    writer.writeBoolean(message.allowReconnect);
  }

  static void _writePingMessage(MessagePackWriter writer) {
    writer
      ..writeArrayHeader(1)
      ..writeInt(HubProtocolConstants.pingMessageType);
  }

  static void _writeAckMessage(
    AckMessage message,
    MessagePackWriter writer,
  ) {
    writer
      ..writeArrayHeader(2)
      ..write(HubProtocolConstants.ackMessageType)
      ..write(message.sequenceId);
  }

  static void _writeSequenceMessage(
    SequenceMessage message,
    MessagePackWriter writer,
  ) {
    writer
      ..writeArrayHeader(2)
      ..write(HubProtocolConstants.sequenceMessageType)
      ..write(message.sequenceId);
  }

  static void _packHeaders(
    Map<String, String>? headers,
    MessagePackWriter writer,
  ) {
    if (headers != null) {
      writer.writeMapHeader(headers.length);
      if (headers.isNotEmpty) {
        for (MapEntry<String, String> header in headers.entries) {
          writer
            ..writeString(header.key)
            ..writeString(header.value);
        }
      }
    } else {
      writer.writeMapHeader(0);
    }
  }

  static String? _readInvocationId(MessagePackReader reader) =>
      _readString(reader, "invocationId");

  static bool? _readBoolean(MessagePackReader reader, String field) {
    try {
      return reader.readBoolean();
    } on Exception catch (_) {
      throw FormatException("Reading '$field' as Boolean failed.");
    }
  }

  static int _readInt(MessagePackReader reader, String field) {
    try {
      return reader.readInt();
    } on Exception catch (_) {
      throw FormatException("Reading '$field' as Int32 failed.");
    }
  }

  //   @protected
  //  static String _readStringBinder(MessagePackReader reader, IInvocationBinder binder, String field)
  //   {
  //       try
  //       {
  //         binder.getTarget(utf8Bytes)
  //       }
  //       on Exception catch (ex)
  //       {
  //           throw InvalidDataException($"Reading '{field}' as String failed.", ex);
  //       }
  //   }

  @protected
  static String? _readString(MessagePackReader reader, String field) {
    try {
      return reader.readString();
    } on Exception catch (_) {
      throw FormatException("Reading '$field' as String failed.");
    }
  }

  static int _readMapLength(MessagePackReader reader, String field) {
    try {
      return reader.readMapHeader();
    } on Exception catch (_) {
      throw FormatException("Reading map length for '$field' failed.");
    }
  }

  static int _readArrayLength(MessagePackReader reader, String field) {
    try {
      return reader.readArrayHeader();
    } on Exception catch (_) {
      throw FormatException("Reading array length for '$field' failed.");
    }
  }
}
