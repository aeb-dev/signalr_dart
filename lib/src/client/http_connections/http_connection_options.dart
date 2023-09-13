import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:http/http.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "../../common/http_connections/http_transport_type.dart";
import "../../dotnet/basic_credential.dart";
import "../../dotnet/client_web_socket_options.dart";
import "../../dotnet/transfer_format.dart";
import "web_socket_connection_context.dart";

class HttpConnectionOptions {
  static const int _defaultBufferSize = 1 * 1024 * 1024;

  Map<String, String> headers = <String, String>{};
  List<Uint8List> clientCertificates = <Uint8List>[];
  List<Cookie> cookies = <Cookie>[];
  BasicCredential? credentials;
  // String? proxy;
  int _transportMaxBufferSize = _defaultBufferSize;
  int _applicationMaxBufferSize = _defaultBufferSize;
  late Uri url;
  HttpTransportType transports = HttpTransportType.all;
  bool skipNegotitation = false;
  Future<String?> Function()? accessTokenProvider;
  Duration closeTimeout = const Duration(seconds: 5);
  TransferFormat defaultTransferFormat = TransferFormat.binary;

  Client Function(Client)? httpMessageHandlerFactory;
  Future<WebSocketChannel> Function(
    WebSocketConnectionContext,
    CancellationToken,
  )? webSocketFactory;
  void Function(ClientWebSocketOptions)? webSocketConfiguration;

  bool useStatefulReconnect = false;

  int get transportMaxBufferSize => _transportMaxBufferSize;
  set transportMaxBufferSize(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, "value");
    }

    _transportMaxBufferSize = value;
  }

  int get applicationMaxBufferSize => _applicationMaxBufferSize;
  set applicationMaxBufferSize(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, "value");
    }

    _applicationMaxBufferSize = value;
  }
}
