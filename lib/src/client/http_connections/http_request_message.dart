import "package:http/http.dart";

class HttpRequestMessage extends Request {
  final Map<String, Object> _options;
  Map<String, Object> get options => _options;

  HttpRequestMessage(
    super.method,
    super.url, {
    Map<String, Object>? options,
  }) : _options = options ?? <String, Object>{};
}
