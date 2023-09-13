import "dart:io";

import "package:http/http.dart";
import "package:meta/meta.dart";

import "../http_connection_options.dart";

abstract class HttpMessageHandler with BaseClient {
  final Client innerClient;

  @protected
  final HttpConnectionOptions httpConnectionOptions;

  HttpMessageHandler(
    this.innerClient,
    this.httpConnectionOptions,
  );

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    request.headers.addAll(httpConnectionOptions.headers);
    if (httpConnectionOptions.cookies.isNotEmpty) {
      request.headers[HttpHeaders.cookieHeader] =
          httpConnectionOptions.cookies.join(";");
    }

    if (httpConnectionOptions.credentials != null) {
      String? headerValue = request.headers[HttpHeaders.authorizationHeader];
      if (headerValue == null) {
        request.headers[HttpHeaders.authorizationHeader] =
            httpConnectionOptions.credentials!.encodedValue();
      }
    }

    StreamedResponse response = await innerClient.send(request);
    return response;
  }
}
