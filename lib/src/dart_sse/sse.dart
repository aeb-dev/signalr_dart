import "package:http/http.dart";

import "sse_client.dart";

SseClient createClient(Uri uri, [Client? httpClient]) => throw UnsupportedError(
      "Cannot create a client without dart:html or dart:io.",
    );
