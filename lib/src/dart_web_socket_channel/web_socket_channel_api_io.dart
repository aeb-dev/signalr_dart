import "dart:io";

import "package:web_socket_channel/io.dart";
import "package:web_socket_channel/web_socket_channel.dart";

WebSocketChannel connect(
  Uri uri, {
  Iterable<String>? protocols,
  Map<String, dynamic>? headers,
  Duration? pingInterval,
  Duration? connectTimeout,
  dynamic httpClient,
}) =>
    IOWebSocketChannel.connect(
      uri,
      protocols: protocols,
      headers: headers,
      pingInterval: pingInterval,
      connectTimeout: connectTimeout,
      customClient: httpClient as HttpClient?,
    );
