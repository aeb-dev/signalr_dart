import "dart:convert";
import "dart:typed_data";

import "package:jsontool/jsontool.dart";
import "package:typed_data/typed_buffers.dart";

import "../../../../dotnet/i_duplex_pipe.dart";
import "../../../../dotnet/invalid_operation_exception.dart";
import "../../../../dotnet/transfer_format.dart";
import "../../../shared/text_message_formatter.dart";
import "../../../shared/text_message_parser.dart";
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
import "../../../signalr/protocol/i_hub_protocol.dart";
import "../../../signalr/protocol/invocation_binding_failure_message.dart";
import "../../../signalr/protocol/invocation_message.dart";
import "../../../signalr/protocol/ping_message.dart";
import "../../../signalr/protocol/raw_result.dart";
import "../../../signalr/protocol/sequence_message.dart";
import "../../../signalr/protocol/stream_binding_failure_message.dart";
import "../../../signalr/protocol/stream_item_message.dart";

class JsonHubProtocol implements IHubProtocol {
  static const String _resultPropertyName = "result";
  static const String _itemPropertyName = "item";
  static const String _invocationIdPropertyName = "invocationId";
  static const String _streamIdsPropertyName = "streamIds";
  static const String _typePropertyName = "type";
  static const String _errorPropertyName = "error";
  static const String _allowReconnectPropertyName = "allowReconnect";
  static const String _targetPropertyName = "target";
  static const String _argumentsPropertyName = "arguments";
  static const String _headersPropertyName = "headers";
  static const String _sequenceIdPropertyName = "sequenceId";

  static const String _protocolName = "json";
  static const int _protocolVersion = 1;

  @override
  String get name => _protocolName;

  @override
  int get version => _protocolVersion;

  @override
  TransferFormat get transferFormat => TransferFormat.text;

  @override
  bool isVersionSupported(int version) => this.version == version;

  @override
  (
    HubMessage? message,
    int consumed,
  ) tryParseMessage(
    Uint8List input,
    IInvocationBinder binder,
  ) {
    var (
      Uint8List? payload,
      int consumed,
    ) = TextMessageParser.tryParseMessage(input);

    if (payload == null) {
      return (
        null,
        consumed,
      );
    }

    HubMessage? message = _parseMessage(
      payload,
      binder,
    );

    return (message, consumed);
  }

  @override
  void writeMessage(HubMessage message, BufferWriter output) {
    _writeMessageCore(message, output);
    TextMessageFormatter.writeRecordSeparator(output);
  }

  @override
  Uint8List getMessageBytes(HubMessage message) {
    Uint8Buffer buffer = Uint8Buffer();

    ByteConversionSink memoryBufferWriter =
        ByteConversionSink.withCallback(buffer.addAll);

    BufferWriter bufferWriter = BufferWriter(memoryBufferWriter);
    writeMessage(message, bufferWriter);
    memoryBufferWriter.close();
    return buffer.buffer.asUint8List();
  }

  HubMessage? _parseMessage(
    Uint8List input,
    IInvocationBinder binder,
  ) {
    try {
      // We parse using the Utf8JsonReader directly but this has a problem. Some of our properties are dependent on other properties
      // and since reading the json might be unordered, we need to store the parsed content as JsonDocument to re-parse when true types are known.
      // if we're lucky and the state we need to directly parse is available, then we'll use it.

      int? type;
      String? invocationId;
      String? target;
      String? error;
      bool hasItem = false;
      Object? item;
      bool hasResult = false;
      Object? result;
      bool hasArguments = false;
      List<Object?>? arguments;
      List<String> streamIds = <String>[];
      bool hasArgumentsToken = false;
      JsonReader<Uint8List>? argumentsToken;
      bool hasItemsToken = false;
      JsonReader<Uint8List>? itemsToken;
      bool hasResultToken = false;
      JsonReader<Uint8List>? resultToken;
      Exception? argumentBindingException;
      StackTrace? argumentBindingStackTrace;
      Map<String, String>? headers;
      bool allowReconnect = false;
      int? sequenceId;

      JsonReader<Uint8List> reader =
          JsonReader.fromUtf8(Uint8List.fromList(input))..expectObject();

      while (true) {
        String? key = reader.nextKey();
        if (key == null) {
          break;
        }

        switch (key) {
          case _typePropertyName:
            type = reader.expectInt();
          case _invocationIdPropertyName:
            invocationId = reader.expectString();
          case _streamIdsPropertyName:
            reader.expectArray();

            while (reader.hasNext()) {
              String streamId = reader.expectString();
              streamIds.add(streamId);
            }
          case _targetPropertyName:
            target = reader.expectString();
          case _errorPropertyName:
            error = reader.expectString();
          case _allowReconnectPropertyName:
            allowReconnect = reader.expectBool();
          case _resultPropertyName:
            hasResult = true;

            if (invocationId == null || invocationId.isEmpty) {
              // If we don't have an invocation id then we need to value copy the reader so we can parse it later
              hasResultToken = true;
              resultToken = reader.copy() as JsonReader<Uint8List>;
              reader.skipAnyValue();
            } else {
              // If we have an invocation id already we can parse the end result
              Type? returnType =
                  ProtocolHelper.tryGetReturnType(binder, invocationId);
              if (returnType == null) {
                reader.skipAnyValue();
                result = null;
              } else {
                try {
                  Object? Function(dynamic)? creator =
                      binder.getReturnTypeCreator(invocationId);
                  result = _bindType(reader, returnType, creator);
                } on Exception catch (ex) {
                  error =
                      "Error trying to deserialize result to $returnType. $ex";
                  hasResult = false;
                }
              }
            }
          case _itemPropertyName:
            hasItem = true;
            String? id;

            if (invocationId != null && invocationId.isNotEmpty) {
              id = invocationId;
            } else {
              // If we don't have an id yet then we need to value copy the reader so we can parse it later
              hasItemsToken = true;
              itemsToken = reader.copy() as JsonReader<Uint8List>;
              reader.skipAnyValue();
              continue;
            }

            try {
              Type itemType = binder.getStreamItemType(id);
              Object? Function(dynamic)? creator =
                  binder.getReturnTypeCreator(id);
              item = _bindType(reader, itemType, creator);
            } on Exception catch (ex, st) {
              return StreamBindingFailureMessage(id, ex, st);
            }
          case _argumentsPropertyName:
            reader.expectArray();

            hasArguments = true;

            if (target == null || target.isEmpty) {
              // We don't know the method name yet so just value copy the reader so we can parse it later
              hasArgumentsToken = true;
              argumentsToken = reader.copy() as JsonReader<Uint8List>;
              reader.skipAnyValue();
            } else {
              try {
                List<Type> paramTypes = binder.getParameterTypes(target);
                List<Object? Function(dynamic)?> creators =
                    binder.getParameterTypesCreator(target);
                arguments = _bindTypes(reader, paramTypes, creators);
              } on Exception catch (ex, st) {
                argumentBindingException = ex;
                argumentBindingStackTrace = st;

                while (reader.hasNext()) {
                  reader.skipAnyValue();
                }
              }
            }
          case _headersPropertyName:
            headers = _readHeaders(reader);
          case _sequenceIdPropertyName:
            sequenceId = reader.expectInt();
          default:
            reader.skipAnyValue();
        }
      }

      HubMessage message;

      switch (type) {
        case HubProtocolConstants.invocationMessageType:
          {
            if (target == null) {
              throw const FormatException(
                "Missing required property '$_targetPropertyName'.",
              );
            }

            if (hasArgumentsToken) {
              // We weren't able to bind the arguments because they came before the 'target', so try to bind now that we've read everything.
              try {
                List<Type> paramTypes = binder.getParameterTypes(target);
                List<Object? Function(dynamic)?> creators =
                    binder.getParameterTypesCreator(target);
                arguments = _bindTypes(argumentsToken!, paramTypes, creators);
              } on Exception catch (ex, st) {
                argumentBindingException = ex;
                argumentBindingStackTrace = st;
              }
            }

            message = argumentBindingException != null
                ? InvocationBindingFailureMessage(
                    invocationId,
                    target,
                    argumentBindingException,
                    argumentBindingStackTrace!,
                  )
                : _bindInvocationMessage(
                    invocationId,
                    target,
                    arguments,
                    hasArguments,
                    streamIds,
                  );
          }
        case HubProtocolConstants.streamInvocationMessageType:
          {
            if (target == null) {
              throw const FormatException(
                "Missing required property '$_targetPropertyName'.",
              );
            }

            if (hasArgumentsToken) {
              // We weren't able to bind the arguments because they came before the 'target', so try to bind now that we've read everything.
              try {
                List<Type> paramTypes = binder.getParameterTypes(target);
                List<Object? Function(dynamic)?> creators =
                    binder.getParameterTypesCreator(target);
                arguments = _bindTypes(argumentsToken!, paramTypes, creators);
              } on Exception catch (ex, st) {
                argumentBindingException = ex;
                argumentBindingStackTrace = st;
              }
            }

            message = argumentBindingException != null
                ? InvocationBindingFailureMessage(
                    invocationId,
                    target,
                    argumentBindingException,
                    argumentBindingStackTrace!,
                  )
                : _bindStreamInvocationMessage(
                    invocationId,
                    target,
                    arguments,
                    hasArguments,
                    streamIds,
                  );
          }
        case HubProtocolConstants.streamItemMessageType:
          if (invocationId == null) {
            throw const FormatException(
              "Missing required property '{$_invocationIdPropertyName}'.",
            );
          }

          if (hasItemsToken) {
            try {
              Type returnType = binder.getStreamItemType(invocationId);
              Object? Function(dynamic)? creator =
                  binder.getReturnTypeCreator(invocationId);
              item = _bindType(itemsToken!, returnType, creator);
            } on Exception catch (ex, st) {
              message = StreamBindingFailureMessage(invocationId, ex, st);
              break;
            }
          }

          message = _bindStreamItemMessage(invocationId, item, hasItem);
        case HubProtocolConstants.completionMessageType:
          if (invocationId == null) {
            throw const FormatException(
              "Missing required property '$_invocationIdPropertyName'.",
            );
          }

          if (hasResultToken) {
            Type? returnType =
                ProtocolHelper.tryGetReturnType(binder, invocationId);
            if (returnType == null) {
              result = null;
            } else {
              try {
                Object? Function(dynamic)? creator =
                    binder.getReturnTypeCreator(invocationId);
                result = _bindType(resultToken!, returnType, creator);
              } on Exception catch (ex) {
                error =
                    "Error trying to deserialize result to $returnType. $ex";
                hasResult = false;
              }
            }
          }

          message =
              _bindCompletionMessage(invocationId, error, result, hasResult);
        case HubProtocolConstants.cancelInvocationMessageType:
          message = _bindCancelInvocationMessage(invocationId);
        case HubProtocolConstants.pingMessageType:
          return PingMessage.instance;
        case HubProtocolConstants.closeMessageType:
          return _bindCloseMessage(error, allowReconnect);
        case HubProtocolConstants.ackMessageType:
          return _bindAckMessage(sequenceId);
        case HubProtocolConstants.sequenceMessageType:
          return _bindSequenceMessage(sequenceId);
        case null:
          throw const FormatException(
            "Missing required property '$_typePropertyName'.",
          );
        default:
          // Future protocol changes can add message types, old clients can ignore them
          return null;
      }

      return _applyHeaders(message, headers);
    } on Exception {
      throw const FormatException("Error reading JSON.");
    }
  }

  static Map<String, String> _readHeaders(JsonReader<Uint8List> reader) {
    Map<String, String> headers = <String, String>{};

    reader.expectObject();

    while (true) {
      String? key = reader.nextKey();
      if (key == null) {
        break;
      }
      headers[key] = reader.expectString();
    }

    throw const FormatException("Unexpected end when reading message headers");
  }

  void _writeMessageCore(HubMessage message, BufferWriter stream) {
    JsonWriter<List<int>> writer = jsonByteWriter(stream.sink)..startObject();
    switch (message) {
      case InvocationMessage m:
        writeMessageType(writer, HubProtocolConstants.invocationMessageType);
        _writeHeaders(writer, m);
        _writeInvocationMessage(m, writer);
      case StreamInvocationMessage m:
        writeMessageType(
          writer,
          HubProtocolConstants.streamInvocationMessageType,
        );
        _writeHeaders(writer, m);
        _writeStreamInvocationMessage(m, writer);
      case StreamItemMessage m:
        writeMessageType(writer, HubProtocolConstants.streamItemMessageType);
        _writeHeaders(writer, m);
        _writeStreamItemMessage(m, writer);
      case CompletionMessage m:
        writeMessageType(writer, HubProtocolConstants.completionMessageType);
        _writeHeaders(writer, m);
        _writeCompletionMessage(m, writer);
      case CancelInvocationMessage m:
        writeMessageType(
          writer,
          HubProtocolConstants.cancelInvocationMessageType,
        );
        _writeHeaders(writer, m);
        _writeCancelInvocationMessage(m, writer);
      case PingMessage _:
        writeMessageType(writer, HubProtocolConstants.pingMessageType);
      case CloseMessage m:
        writeMessageType(writer, HubProtocolConstants.closeMessageType);
        _writeCloseMessage(m, writer);
      case AckMessage m:
        writeMessageType(writer, HubProtocolConstants.ackMessageType);
        _writeAckMessage(m, writer);
      case SequenceMessage m:
        writeMessageType(writer, HubProtocolConstants.sequenceMessageType);
        _writeSequenceMessage(m, writer);
      default:
        throw InvalidOperationException(
          "Unsupported message type: ${message.runtimeType}",
        );
    }
    writer.endObject();
  }

  static void _writeHeaders(
    JsonWriter<List<int>> writer,
    HubInvocationMessage message,
  ) {
    if (message.headers.isNotEmpty) {
      writer
        ..addKey(_headersPropertyName)
        ..startObject();
      for (MapEntry<String, String> kv in message.headers.entries) {
        writer
          ..addKey(kv.key)
          ..addString(kv.value);
      }
      writer.endObject();
    }
  }

  void _writeCompletionMessage(
    CompletionMessage message,
    JsonWriter<List<int>> writer,
  ) {
    _writeInvocationId(message, writer);
    if (message.error != null && message.error!.isNotEmpty) {
      writer
        ..addKey(_errorPropertyName)
        ..addString(message.error!);
    } else if (message.hasResult) {
      writer.addKey(_resultPropertyName);
      if (message.result == null) {
        writer.addNull();
      } else {
        if (message.result is RawResult) {
          RawResult rawResult = message.result! as RawResult;
          writer.addSourceValue(rawResult.rawSerializedData);
        } else {
          List<int> data =
              json.encoder.fuse(utf8.encoder).convert(message.result);
          writer.addSourceValue(data);
        }
      }
    }
  }

  static void _writeCancelInvocationMessage(
    CancelInvocationMessage message,
    JsonWriter<List<int>> writer,
  ) {
    _writeInvocationId(message, writer);
  }

  void _writeStreamItemMessage(
    StreamItemMessage message,
    JsonWriter<List<int>> writer,
  ) {
    _writeInvocationId(message, writer);
    writer.addKey(_itemPropertyName);
    if (message.item == null) {
      writer.addNull();
    } else {
      List<int> data = json.encoder.fuse(utf8.encoder).convert(message.item);
      writer.addSourceValue(data);
    }
  }

  void _writeInvocationMessage(
    InvocationMessage message,
    JsonWriter<List<int>> writer,
  ) {
    _writeInvocationId(message, writer);
    writer
      ..addKey(_targetPropertyName)
      ..addString(message.target);

    _writeArguments(message.arguments, writer);

    _writeStreamIds(message.streamIds, writer);
  }

  void _writeStreamInvocationMessage(
    StreamInvocationMessage message,
    JsonWriter<List<int>> writer,
  ) {
    _writeInvocationId(message, writer);
    writer
      ..addKey(_targetPropertyName)
      ..addString(message.target);

    _writeArguments(message.arguments, writer);

    _writeStreamIds(message.streamIds, writer);
  }

  static void _writeCloseMessage(
    CloseMessage message,
    JsonWriter<List<int>> writer,
  ) {
    if (message.error != null) {
      writer
        ..addKey(_errorPropertyName)
        ..addString(message.error!);
    }

    if (message.allowReconnect) {
      writer
        ..addKey(_allowReconnectPropertyName)
        ..addBool(message.allowReconnect);
    }
  }

  static void _writeAckMessage(
    AckMessage message,
    JsonWriter<List<int>> writer,
  ) {
    writer
      ..addKey(_sequenceIdPropertyName)
      ..addNumber(message.sequenceId);
  }

  static void _writeSequenceMessage(
    SequenceMessage message,
    JsonWriter<List<int>> writer,
  ) {
    writer
      ..addKey(_sequenceIdPropertyName)
      ..addNumber(message.sequenceId);
  }

  void _writeArguments(List<Object?> arguments, JsonWriter<List<int>> writer) {
    writer
      ..addKey(_argumentsPropertyName)
      ..startArray();
    for (Object? argument in arguments) {
      if (argument == null) {
        writer.addNull();
      } else {
        List<int> data = json.encoder.fuse(utf8.encoder).convert(argument);
        writer.addSourceValue(data);
      }
    }
    writer.endArray();
  }

  static void _writeStreamIds(
    List<String>? streamIds,
    JsonWriter<List<int>> writer,
  ) {
    if (streamIds == null) {
      return;
    }

    writer
      ..addKey(_streamIdsPropertyName)
      ..startArray();

    for (String streamId in streamIds) {
      writer.addString(streamId);
    }
    writer.endArray();
  }

  static void _writeInvocationId(
    HubInvocationMessage message,
    JsonWriter<List<int>> writer,
  ) {
    if (message.invocationId != null && message.invocationId!.isNotEmpty) {
      writer
        ..addKey(_invocationIdPropertyName)
        ..addString(message.invocationId!);
    }
  }

  static void writeMessageType(JsonWriter<List<int>> writer, int type) {
    writer
      ..addKey(_typePropertyName)
      ..addNumber(type);
  }

  static HubMessage _bindCancelInvocationMessage(String? invocationId) {
    if (invocationId == null || invocationId.isEmpty) {
      throw const FormatException(
        "Missing required property '{$_invocationIdPropertyName}'.",
      );
    }

    return CancelInvocationMessage(invocationId);
  }

  static HubMessage _bindCompletionMessage(
    String? invocationId,
    String? error,
    Object? result,
    bool hasResult,
  ) {
    if (invocationId == null || invocationId.isEmpty) {
      throw const FormatException(
        "Missing required property '{$_invocationIdPropertyName}'.",
      );
    }

    if (error != null && hasResult) {
      throw const FormatException(
        "The 'error' and 'result' properties are mutually exclusive.",
      );
    }

    if (hasResult) {
      return CompletionMessage(invocationId, error, result, true);
    }

    return CompletionMessage(invocationId, error, null, false);
  }

  static HubMessage _bindStreamItemMessage(
    String? invocationId,
    Object? item,
    bool hasItem,
  ) {
    if (invocationId == null || invocationId.isEmpty) {
      throw const FormatException(
        "Missing required property '{$_invocationIdPropertyName}'.",
      );
    }

    if (!hasItem) {
      throw const FormatException(
        "Missing required property '{$_itemPropertyName}'.",
      );
    }

    return StreamItemMessage(invocationId, item);
  }

  static HubMessage _bindStreamInvocationMessage(
    String? invocationId,
    String? target,
    List<Object?>? arguments,
    bool hasArguments,
    List<String>? streamIds,
  ) {
    if (invocationId == null || invocationId.isEmpty) {
      throw const FormatException(
        "Missing required property '{$_invocationIdPropertyName}'.",
      );
    }

    if (!hasArguments) {
      throw const FormatException(
        "Missing required property '{$_argumentsPropertyName}'.",
      );
    }

    if (target == null || target.isEmpty) {
      throw const FormatException(
        "Missing required property '$_targetPropertyName'.",
      );
    }

    return StreamInvocationMessage(invocationId, target, arguments!, streamIds);
  }

  static HubMessage _bindInvocationMessage(
    String? invocationId,
    String? target,
    List<Object?>? arguments,
    bool hasArguments,
    List<String>? streamIds,
  ) {
    if (target == null || target.isEmpty) {
      throw const FormatException(
        "Missing required property '$_targetPropertyName'.",
      );
    }

    if (!hasArguments) {
      throw const FormatException(
        "Missing required property '{$_argumentsPropertyName}'.",
      );
    }

    return InvocationMessage(invocationId, target, arguments!, streamIds);
  }

  Object? _bindType(
    JsonReader<Uint8List> reader,
    Type type,
    Object? Function(Object?)? creator,
  ) {
    if (type == RawResult) {
      Uint8List data = reader.expectAnyValueSource();
      // Review: Technically the sequence doesn't need to be copied to a new array in RawResult
      // but in the future we could break this if we dispatched the CompletionMessage and the underlying Pipe read would be advanced
      // instead we could try pooling in RawResult, but it would need release/dispose semantics
      return RawResult(data);
    } else {
      Uint8List data = reader.expectAnyValueSource();

      Object? result = utf8.decoder.fuse(json.decoder).convert(data);

      if (result != null && creator != null) {
        result = creator(result);
      }

      return result;
    }
  }

  List<Object?> _bindTypes(
    JsonReader<Uint8List> reader,
    List<Type> paramTypes,
    List<Object? Function(dynamic)?> creators,
  ) {
    int paramIndex = 0;
    int paramCount = paramTypes.length;
    List<Object?> arguments = List<Object?>.filled(paramCount, null);

    while (reader.hasNext()) {
      if (paramIndex < paramCount) {
        try {
          arguments[paramIndex] = _bindType(
            reader,
            paramTypes[paramIndex],
            creators[paramIndex],
          );
        } on Exception {
          throw const FormatException(
            "Error binding arguments. Make sure that the types of the provided values match the types of the hub method being invoked.",
          );
        }
      } else {
        // Skip extra arguments and throw error after reading them all
        reader.skipAnyValue();
      }
      paramIndex++;
    }

    if (paramIndex != paramCount) {
      throw FormatException(
        "Invocation provides $paramIndex argument(s) but target expects $paramCount.",
      );
    }

    return arguments;
  }

  static CloseMessage _bindCloseMessage(String? error, bool allowReconnect) {
    // An empty string is still an error
    if (error == null && !allowReconnect) {
      return CloseMessage.empty;
    }

    return CloseMessage(error, allowReconnect);
  }

  static AckMessage _bindAckMessage(int? sequenceId) {
    if (sequenceId == null) {
      throw const FormatException("Missing required property 'sequenceId'");
    }

    return AckMessage(sequenceId);
  }

  static SequenceMessage _bindSequenceMessage(int? sequenceId) {
    if (sequenceId == null) {
      throw const FormatException("Missing required property 'sequenceId'");
    }

    return SequenceMessage(sequenceId);
  }

  static HubMessage _applyHeaders(
    HubMessage message,
    Map<String, String>? headers,
  ) {
    if (headers != null && message is HubInvocationMessage) {
      message.headers = headers;
    }

    return message;
  }
}
