import "dart:io";

import "package:http/http.dart";

import "../http_connection.dart";
import "../http_request_message.dart";
import "http_message_handler.dart";

class AccessTokenHttpMessageHandler extends HttpMessageHandler {
  String? _accessToken;
  final HttpConnection _httpConnection;

  AccessTokenHttpMessageHandler(
    HttpConnection httpConnection,
    super.inner,
    super.httpConnectionOptions,
  ) : _httpConnection = httpConnection;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    bool shouldRetry = true;
    if (_accessToken == null && request is HttpRequestMessage) {
      Object? value = request.options["IsNegotiate"];
      if (value != null && (value as bool)) {
        shouldRetry = false;
        _accessToken = await _httpConnection.getAccessToken();
      }
    }

    _setAccessToken(_accessToken, request);

    StreamedResponse result = await super.send(request);
    // retry once with a new token on auth failure
    if (shouldRetry && result.statusCode == HttpStatus.unauthorized) {
      Log.retryAccessToken(_httpConnection.logger, result.statusCode);
      _accessToken = await _httpConnection.getAccessToken();

      _setAccessToken(_accessToken, request);

      // Retrying the request relies on any HttpContent being non-disposable.
      // Currently this is true, the only HttpContent we send is type ReadOnlySequenceContent which is used by SSE and LongPolling for sending an already buffered byte[]
      result = await super.send(request);
    }
    return result;
  }

  static void _setAccessToken(String? accessToken, BaseRequest request) {
    if (accessToken != null && accessToken.isNotEmpty) {
      // Don't need to worry about WebSockets and browser because this code path will not be hit in the browser case
      // ClientWebSocketOptions.HttpVersion isn't settable in the browser
      request.headers[HttpHeaders.authorizationHeader] = "Bearer $accessToken";
    }
  }
}
