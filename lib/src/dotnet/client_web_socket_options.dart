import "dart:io";
import "dart:typed_data";

import "basic_credential.dart";
import "http_version.dart";

class ClientWebSocketOptions {
  final List<Cookie> cookies = <Cookie>[];
  final List<Uint8List> clientCertificates = <Uint8List>[];
  final Map<String, String> headers = <String, String>{};
  bool? useDefaultCredentials;
  BasicCredential? credentials;
  HttpVersion httpVersion = HttpVersion.version11;
}
