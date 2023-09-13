import "dart:typed_data";

import "../../../dotnet/i_duplex_pipe.dart";
import "../../../dotnet/transfer_format.dart";
import "../i_invocation_binder.dart";
import "hub_message.dart";

abstract interface class IHubProtocol {
  String get name;
  int get version;
  TransferFormat get transferFormat;

  (
    HubMessage? message,
    int consumed,
  ) tryParseMessage(
    Uint8List input,
    IInvocationBinder binder,
  );
  void writeMessage(HubMessage hubMessage, BufferWriter output);
  Uint8List getMessageBytes(HubMessage hubMessage);
  bool isVersionSupported(int version);
}
