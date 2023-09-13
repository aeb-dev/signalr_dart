import "dart:typed_data";

import "../../../../dotnet/i_duplex_pipe.dart";
import "../../../../dotnet/transfer_format.dart";
import "../../../signalr/i_invocation_binder.dart";
import "../../../signalr/protocol/hub_message.dart";
import "../../../signalr/protocol/i_hub_protocol.dart";
import "default_message_pack_hub_protocol_worker.dart";

class MessagePackHubProtocol implements IHubProtocol {
  static const String _protocolName = "messagepack";
  static const int _protocolVersion = 1;
  final DefaultMessagePackHubProtocolWorker _worker;

  @override
  String get name => _protocolName;

  @override
  int get version => _protocolVersion;

  @override
  TransferFormat get transferFormat => TransferFormat.binary;

  MessagePackHubProtocol() : _worker = DefaultMessagePackHubProtocolWorker();

  @override
  bool isVersionSupported(int version) => version == version;

  @override
  (
    HubMessage? message,
    int consumed,
  ) tryParseMessage(Uint8List input, IInvocationBinder binder) =>
      _worker.tryParseMessage(input, binder);

  @override
  void writeMessage(HubMessage message, BufferWriter output) =>
      _worker.writeMessage(message, output);

  @override
  Uint8List getMessageBytes(HubMessage message) =>
      _worker.getMessageBytes(message);
}
