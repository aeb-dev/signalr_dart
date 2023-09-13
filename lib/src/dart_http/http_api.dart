import "package:http/http.dart";

BaseClient createClient([dynamic innerClient]) => throw UnsupportedError(
      "Cannot create a client without dart:html or dart:io.",
    );
