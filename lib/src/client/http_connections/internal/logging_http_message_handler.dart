// ignore_for_file: avoid_classes_with_only_static_members

import "dart:io";

import "package:http/http.dart";
import "package:logging/logging.dart";

import "../../../extensions/base_response.dart";
import "http_message_handler.dart";

class LoggingHttpMessageHandler extends HttpMessageHandler {
  final Logger _logger = Logger("LoggingHttpMessageHandler");

  LoggingHttpMessageHandler(super.innerClient, super.httpConnectionOptions);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    _Log.sendingHttpRequest(_logger, request.method, request.url);

    // StreamedResponse response = await super.send(request, cancellationToken);
    StreamedResponse response = await super.send(request);

    if (!response.isSuccessStatusCode &&
        response.statusCode != HttpStatus.switchingProtocols) {
      _Log.unsuccessfulHttpResponse(
        _logger,
        response.statusCode,
        request.method,
        request.url,
      );
    }

    return response;
  }
}

class _Log {
  static void sendingHttpRequest(
    Logger logger,
    String requestMethod,
    Uri requestUrl,
  ) {
    logger.log(
      Level.FINEST,
      "Sending HTTP request $requestMethod '$requestUrl'.",
    );
  }

  static void unsuccessfulHttpResponse(
    Logger logger,
    int statusCode,
    String requestMethod,
    Uri requestUrl,
  ) {
    logger.log(
      Level.FINEST,
      "Unsuccessful HTTP response $statusCode return from $requestMethod '$requestUrl'.",
    );
  }
}
