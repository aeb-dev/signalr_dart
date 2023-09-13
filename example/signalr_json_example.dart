// ignore_for_file: unreachable_from_main

import "dart:developer";

import "package:logging/logging.dart";
import "package:signalr_dart/signalr_dart.dart";

import "signalr_contracts.dart";

Future<void> main() async {
  Logger logger = Logger("json_example");
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((LogRecord record) {
    log("${record.level.name}: ${record.time}: ${record.message}");
  });

  // You can use the following server for testing
  // https://github.com/aeb-dev/signalr_dart_test_server
  Uri uri = Uri.parse("https://localhost:7022/testHub");
  HubConnection hubConnection = HubConnectionBuilder.withUrl(
    uri,
    (HttpConnectionOptions connOpt) {
      // If you want to client to select best option don't pass anything
      // If you want to select multiple use like following
      // HttpTransportType.serverSentEvents | HttpTransportType.longPolling
      connOpt.transports = HttpTransportType.serverSentEvents;
      connOpt.headers["X-Test"] = "signalr-dart";
      connOpt.accessTokenProvider = () async => "FISOZDNEID";
    },
  ).withStatefulReconnect().build();

  int messageId = 0;

  await hubConnection.start();

  hubConnection.onResult1(
    "Calculate",
    (ServerRequest sr) {
      logger.info("Server request: \n$sr");

      return ClientResponse(
        ++messageId,
        sr.messageId,
        "Then your age is 8",
        DateTime.timestamp(),
        0.99,
        <String, dynamic>{
          "1": 1,
          "2": "item2",
          "3": null,
        },
        sr,
      );
    },
    ServerRequest.fromJson,
  );

  while (true) {
    ServerResponse sr = await hubConnection.invoke1(
      "AskAge",
      ClientRequest(
        ++messageId,
        "how old are you",
        DateTime.timestamp(),
      ),
      ServerResponse.fromJson,
    );

    logger.info("Server response: \n$sr");

    await hubConnection.send0("Greet");

    await for (int event in hubConnection.stream1<int>(
      "Count",
      Stream<int>.fromIterable(<int>[1, 2, 3, 4, 5]),
    )) {
      log("Stream item value: $event");
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }

  // s.dispose();
}
