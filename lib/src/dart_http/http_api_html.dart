import "package:http/browser_client.dart";
import "package:http/http.dart";

BaseClient createClient([dynamic innerClient]) {
  if (const bool.fromEnvironment("no_default_http_client")) {
    throw StateError(
      "no_default_http_client was defined but runWithClient "
      "was not used to configure a Client implementation.",
    );
  }
  return BrowserClient();
}
