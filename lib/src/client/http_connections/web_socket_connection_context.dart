import "http_connection_options.dart";

class WebSocketConnectionContext {
  final Uri uri;
  final HttpConnectionOptions options;

  const WebSocketConnectionContext(
    this.uri,
    this.options,
  );
}
