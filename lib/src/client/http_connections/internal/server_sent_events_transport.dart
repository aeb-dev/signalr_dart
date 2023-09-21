import "dart:async";
import "dart:typed_data";

import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:http/http.dart";
import "package:logging/logging.dart";
import "package:os_detect/os_detect.dart" as platform;

import "../../../common/shared/duplex_pipe.dart";
import "../../../dart_sse/sse.dart"
    if (dart.library.io) "../../../dart_sse/sse_io.dart"
    if (dart.library.html) "../../../dart_sse/sse_html.dart" as sse_client;
import "../../../dart_sse/sse_client.dart";
import "../../../dotnet/i_duplex_pipe.dart";

import "../../../dotnet/transfer_format.dart";
import "i_transport.dart";
import "send_utils.dart";
import "server_sent_events_message_parser.dart";

part "server_sent_events_transport.log.dart";

class ServerSentEventsTransport implements ITransport {
  final Client _httpClient;
  final Logger _logger = Logger("ServerSentEventsTransport");
  Exception? _error;
  StackTrace? _stackTrace;
  final CancellationTokenSource _transportCts = CancellationTokenSource();
  final CancellationTokenSource _inputCts = CancellationTokenSource();
  final ServerSentEventsMessageParser _parser = ServerSentEventsMessageParser();
  // final bool _useStatefulReconnect;
  IDuplexPipe? _transport;
  IDuplexPipe? _application;

  Future<void> running = Future<void>.value();

  ServerSentEventsTransport(
    Client httpClient, {
    bool useStatefulReconnect = false,
  })  : _httpClient = httpClient;
        // _useStatefulReconnect = useStatefulReconnect;

  @override
  BufferReader get input => _transport!.input;

  @override
  BufferWriter get output => _transport!.output;

  @override
  Future<void> start(
    Uri url,
    TransferFormat transferFormat, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    if (transferFormat != TransferFormat.text) {
      throw ArgumentError(
        "The '$transferFormat' transfer format is not supported by this transport.",
      );
    }

    _Log.startTransport(_logger, transferFormat);

    SseClient sseClient;
    try {
      sseClient = sse_client.createClient(url, _httpClient);
      await sseClient.ready;
    } on Exception catch (_) {
      _Log.transportStopping(_logger);

      rethrow;
    }

    // Create the pipe pair (Application's writer is connected to Transport's reader, and vice versa)
    var (
      IDuplexPipe transport,
      IDuplexPipe application,
    ) = DuplexPipe.createConnectionPair();

    _transport = transport;
    _application = application;

    // Cancellation token will be triggered when the pipe is stopped on the client.
    // This is to avoid the client throwing from a 404 response caused by the
    // server stopping the connection while the send message request is in progress.
    // _application.Input.OnWriterCompleted((exception, state) => ((CancellationTokenSource)state).Cancel(), inputCts);

    running = _process(url, sseClient);
  }

  Future<void> _process(Uri url, SseClient sseClient) async {
    // Start sending and polling (ask for binary if the server supports it)
    bool isReceiving = false;
    Future<void> receiving = _processEventStream(
      sseClient.stream,
      _transportCts.token,
    ).whenComplete(() => isReceiving = true);
    Future<void> sending = SendUtils.sendSseMessages(
      url,
      _application!,
      sseClient,
      _logger,
      _inputCts.token,
    )
        .whenComplete(() => isReceiving = false)
        .catchError((Object ex, StackTrace st) => _error = ex as Exception);

    // Wait for send or receive to complete
    await Future.any<void>(<Future<void>>[receiving, sending]);

    if (isReceiving) {
      // We're waiting for the application to finish and there are 2 things it could be doing
      // 1. Waiting for application data
      // 2. Waiting for an outgoing send (this should be instantaneous)

      await _inputCts.cancel();

      // Cancel the application so that ReadAsync yields
      _application!.input.cancelPendingRead();

      await sending;
    } else {
      await _transportCts.cancel();

      await receiving;
    }
  }

  Future<void> _processEventStream(
    Stream<List<int>> responseStream,
    CancellationToken cancellationToken,
  ) async {
    _Log.startReceive(_logger);

    BufferReader reader = BufferReader(responseStream);

    CancellationTokenRegistration registration = cancellationToken.register(
      callback: (_, __) => reader.cancelPendingRead(),
      state: reader,
    );

    try {
      while (true) {
        // We rely on the CancelReader callback to cancel pending reads. Do not pass the token to ReadAsync since that would result in an exception on cancelation.
        ReadResult result = await reader.read();
        Uint8List buffer = result.buffer.sublist(0);
        int consumed_ = 0;

        try {
          if (result.isCancelled) {
            _Log.receiveCanceled(_logger);
            break;
          }

          // We canceled in the middle of applying back pressure
          // or if the consumer is done
          if (_application!.output.isCompleted) {
            _Log.eventStreamEnded(_logger);
            break;
          }

          if (buffer.isNotEmpty) {
            _Log.parsingSSE(_logger, buffer.length);

            parse:
            while (true) {
              Uint8List slice = Uint8List.sublistView(buffer, consumed_);
              if (slice.isEmpty) {
                break;
              }

              if (platform.isBrowser) {
                consumed_ += slice.length;
                _application!.output.add(slice);
              } else {
                var (
                  ParseResult parseResult,
                  List<int>? message,
                  int consumed,
                ) = _parser.parseMessage(slice);

                consumed_ += consumed;

                switch (parseResult) {
                  case ParseResult.completed:
                    _Log.messageToApplication(_logger, message!.length);

                    // When cancellationToken is canceled the next line will cancel pending flushes on the pipe unblocking the await.
                    // Avoid passing the passed in context.
                    _application!.output.add(message);

                    _parser.reset();
                  case ParseResult.incomplete:
                    if (result.isCompleted) {
                      throw const FormatException("Incomplete message.");
                    }
                    break parse;
                }
              }
            }
          } else if (result.isCompleted) {
            break;
          }
        } finally {
          reader.advanceTo(consumed_);
        }
      }
    } on Exception catch (ex, st) {
      _error = ex;
      _stackTrace = st;
    } finally {
      await _application!.output.complete(_error, _stackTrace);
      await reader.dispose();
      registration.dispose();

      _Log.receiveStopped(_logger);
    }
  }

  @override
  Future<void> stop() async {
    _Log.transportStopping(_logger);

    if (_application == null) {
      // We never started
      return;
    }

    await _transport!.output.complete();
    _transport!.input.complete();

    _application!.input.cancelPendingRead();

    try {
      await running;
    } on Exception catch (ex, st) {
      _Log.transportStopped(_logger, ex, st);
      rethrow;
    }

    _Log.transportStopped(_logger);
  }
}
