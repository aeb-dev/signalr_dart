// ignore_for_file: discarded_futures

import "dart:async";
import "dart:io";

import "package:http/http.dart";
import "package:logging/logging.dart";
import "package:pool/pool.dart";

import "../extensions/base_response.dart";
import "sse_client.dart";

final Pool _requestPool = Pool(1);

SseClient createClient(Uri uri, [Client? httpClient]) =>
    IOSseClient(uri, httpClient!);

class IOSseClient extends SseClient {
  final Uri _uri;
  final Client _httpClient;
  final Completer<void> _completer;
  late StreamedResponse _response;
  final StreamController<List<int>> _outgoingController =
      StreamController<List<int>>();

  @override
  Future<void> get ready => _completer.future;

  IOSseClient(
    this._uri,
    this._httpClient,
  ) : _completer = Completer<void>() {
    StreamedRequest request = StreamedRequest("GET", _uri);
    request.headers[HttpHeaders.acceptHeader] = "text/event-stream";

    unawaited(
      _httpClient.send(request).then(
        (StreamedResponse response) {
          response.ensureSuccessStatusCode();
          _response = response;
          _outgoingController.stream.listen(_outgoingMessageHandler);
          _completer.complete();
        },
      ),
    );
    request.sink.close();
  }

  @override
  StreamSink<List<int>> get sink => _outgoingController.sink;

  @override
  Stream<List<int>> get stream => _response.stream;

  Future<void> close() async {
    await _outgoingController.close();
  }

  void _outgoingMessageHandler(List<int> event) {
    add(event);
    List<int>? frame = getFrameIfReady();
    if (frame == null) {
      return;
    }

    logger.log(
      Level.FINE,
      "Sending ${frame.length} bytes to the server using url: $_uri.",
    );

    _requestPool.withResource(() async {
      StreamedRequest request = StreamedRequest("POST", _uri);

      Future<StreamedResponse> responseFuture = _httpClient.send(request);

      request.sink.add(frame);
      request.sink.close();

      StreamedResponse response = await responseFuture;
      response.ensureSuccessStatusCode();

      logger.log(Level.FINE, "Message(s) sent successfully.");
    });
  }
}
