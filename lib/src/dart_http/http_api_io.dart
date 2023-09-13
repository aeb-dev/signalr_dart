import "dart:io";

import "package:http/http.dart";
import "package:http/io_client.dart";

BaseClient createClient([dynamic innerClient]) {
  if (const bool.fromEnvironment("no_default_http_client")) {
    throw StateError(
      "no_default_http_client was defined but runWithClient "
      "was not used to configure a Client implementation.",
    );
  }
  return IOClient(innerClient as HttpClient?);
}
