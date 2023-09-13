import "dart:async";
import "dart:convert";
import "dart:html";
import "dart:typed_data";

import "package:http/http.dart";
import "package:js/js.dart";
import "package:logging/logging.dart";
import "package:pool/pool.dart";

import "sse_client.dart";

SseClient createClient(Uri uri, [Client? httpClient]) => HtmlSseClient(uri);

final Pool _requestPool = Pool(1);

class HtmlSseClient extends SseClient {
  final String _url;
  final StreamController<List<int>> _incomingController =
      StreamController<List<int>>();
  final StreamController<List<int>> _outgoingController =
      StreamController<List<int>>();
  final Completer<void> _onConnected = Completer<void>();
  late EventSource _eventSource;

  HtmlSseClient(Uri url) : _url = url.toString() {
    _eventSource = EventSource(_url, withCredentials: true);
    unawaited(
      _eventSource.onOpen.first.whenComplete(() {
        _onConnected.complete();
        _outgoingController.stream.listen(_outgoingMessageHandler);
      }),
    );
    _eventSource.addEventListener("message", _incomingMessageHandler);
  }

  @override
  Future<void> get ready => _onConnected.future;

  @override
  StreamSink<List<int>> get sink => _outgoingController.sink;

  @override
  Stream<List<int>> get stream => _incomingController.stream;

  Future<void> close() async {
    _eventSource.close();
    await _incomingController.close();
    await _outgoingController.close();
  }

  void _incomingMessageHandler(Event message) {
    List<int> data = utf8.encode((message as MessageEvent).data as String);
    _incomingController.add(data);
  }

  void _outgoingMessageHandler(List<int> message) async {
    add(message);
    Uint8List? frame = getFrameIfReady();
    if (frame == null) {
      return;
    }
    logger.log(
      Level.FINE,
      "Sending ${frame.length} bytes to the server using url: $_url.",
    );

    await _requestPool.withResource(() async {
      await _fetch(
        _url,
        _FetchOptions(
          method: "POST",
          body: frame,
          credentials: "include",
        ),
      );

      logger.log(Level.FINE, "Message(s) sent successfully.");
    });
  }
}

// Custom implementation of Fetch API until Dart supports GET vs. POST,
// credentials, etc. See https://github.com/dart-lang/http/issues/595.
@JS("fetch")
external Object _nativeJsFetch(String resourceUrl, _FetchOptions options);

Future<dynamic> _fetch(String resourceUrl, _FetchOptions options) =>
    promiseToFuture(_nativeJsFetch(resourceUrl, options));

@JS()
@anonymous
class _FetchOptions {
  external factory _FetchOptions({
    required String method, // e.g., 'GET', 'POST'
    required String credentials, // e.g., 'omit', 'same-origin', 'include'
    required dynamic body,
  });
}
