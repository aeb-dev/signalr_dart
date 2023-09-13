import "package:web_socket_channel/html.dart";
import "package:web_socket_channel/web_socket_channel.dart";

WebSocketChannel connect(
  Uri uri, {
  Iterable<String>? protocols,
  Map<String, dynamic>? headers,
  Duration? pingInterval,
  Duration? connectTimeout,
  dynamic httpClient,
}) =>
    HtmlWebSocketChannel.connect(
      uri,
      protocols: protocols,
    );
