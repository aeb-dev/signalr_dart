import "dart:async";
import "dart:io";

import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:http/http.dart";
import "package:logging/logging.dart";

import "../../../common/shared/duplex_pipe.dart";
import "../../../dotnet/i_duplex_pipe.dart";
import "../../../dotnet/transfer_format.dart";
import "../../../extensions/base_response.dart";
import "i_transport.dart";
import "send_utils.dart";

part "long_polling_transport.log.dart";

class LongPollingTransport implements ITransport {
  final Client _httpClient;
  final Logger _logger = Logger("LongPollingTransport");
  // final HttpConnectionOptions _httpConnectionOptions;
  IDuplexPipe? _application;
  final bool _useStatefulReconnect;
  IDuplexPipe? _transport;
  Exception? _error;
  StackTrace? _stackTrace;
  final CancellationTokenSource _transportCts = CancellationTokenSource();

  Future<void> running = Future<void>.value();

  @override
  BufferReader get input => _transport!.input;

  @override
  BufferWriter get output => _transport!.output;

  LongPollingTransport(
    Client httpClient, {
    bool useStatefulReconnect = false,
  })  : _httpClient = httpClient,
        _useStatefulReconnect = useStatefulReconnect;

  @override
  Future<void> start(
    Uri url,
    TransferFormat transferFormat, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    if (transferFormat != TransferFormat.binary &&
        transferFormat != TransferFormat.text) {
      throw ArgumentError(
        "The '$transferFormat' transfer format is not supported by this transport.",
      );
    }

    _Log.startTransport(_logger, transferFormat);

    // Make initial long polling request
    // Server uses first long polling request to finish initializing connection and it returns without data
    Request request = Request("GET", url);
    StreamedResponse response = await _httpClient.send(request);
    response.ensureSuccessStatusCode();

    // Create the pipe pair (Application's writer is connected to Transport's reader, and vice versa)
    var (
      IDuplexPipe transport,
      IDuplexPipe application,
    ) = DuplexPipe.createConnectionPair();

    _transport = transport;
    _application = application;

    running = _process(url);
  }

  Future<void> _process(Uri url) async {
    // Start sending and polling (ask for binary if the server supports it)
    bool isReceiving = false;
    Future<void> receiving =
        _poll(url, _transportCts.token).whenComplete(() => isReceiving = true);
    Future<void> sending = SendUtils.sendMessages(
      url,
      _application!,
      _httpClient,
      _logger,
    )
        .whenComplete(() => isReceiving = false)
        .catchError((Object ex, StackTrace st) => _error = ex as Exception);

    // Wait for send or receive to complete
    await Future.any<void>(<Future<void>>[receiving, sending]);

    if (isReceiving) {
      // We don't need to DELETE here because the poll completed, which means the server shut down already.

      // We're waiting for the application to finish and there are 2 things it could be doing
      // 1. Waiting for application data
      // 2. Waiting for an outgoing send (this should be instantaneous)

      // Cancel the application so that ReadAsync yields
      _application!.input.cancelPendingRead();

      await sending;
    } else {
      // Cancel the poll request
      await _transportCts.cancel();

      await receiving;

      // Send the DELETE request to clean-up the connection on the server.
      await _sendDeleteRequest(url);
    }
  }

  @override
  Future<void> stop() async {
    _Log.transportStopping(_logger);

    if (_application == null) {
      // We never started
      return;
    }

    _application!.input.cancelPendingRead();

    try {
      await running;
    } on Exception catch (ex, st) {
      _Log.transportStopped(_logger, ex, st);
      rethrow;
    }

    await _transport!.output.complete();
    _transport!.input.complete();

    _Log.transportStopped(_logger);
  }

  Future<void> _poll(
    Uri pollUrl,
    CancellationToken cancellationToken,
  ) async {
    _Log.startReceive(_logger);

    try {
      while (!cancellationToken.isCancellationRequested) {
        Request request = Request("GET", pollUrl);

        StreamedResponse response;

        try {
          response = await _httpClient.send(request);
        } on OperationCancelledException {
          // SendAsync will throw the OperationCanceledException if the passed cancellationToken is canceled
          // or if the http request times out due to HttpClient.Timeout expiring. In the latter case we
          // just want to start a new poll.
          continue;
        }

        _Log.pollResponseReceived(
          _logger,
          response.statusCode,
          response.contentLength!,
        );

        response.ensureSuccessStatusCode();

        if (response.statusCode == HttpStatus.noContent ||
            cancellationToken.isCancellationRequested) {
          _Log.closingConnection(_logger);

          // Transport closed or polling stopped, we're done
          break;
        } else {
          _Log.receivedMessages(_logger);
          // We canceled in the middle of applying back pressure
          // or if the consumer is done
          if (_application!.output.isCompleted) {
            break;
          }

          await for (List<int> data in response.stream) {
            _application!.output.add(data);
          }
        }
      }
    } on OperationCancelledException catch (_) {
      // transport is being closed
      _Log.receiveCanceled(_logger);
    } on Exception catch (ex, st) {
      _Log.errorPolling(_logger, pollUrl, ex, st);

      _error = ex;
      _stackTrace = st;
    } finally {
      await _application!.output.complete(_error, _stackTrace);

      _Log.receiveStopped(_logger);
    }
  }

  Future<void> _sendDeleteRequest(Uri url) async {
    try {
      _Log.sendingDeleteRequest(_logger, url);
      Request request = Request("DELETE", url);
      StreamedResponse response = await _httpClient.send(request);

      if (response.statusCode == HttpStatus.notFound) {
        _Log.connectionAlreadyClosedSendingDeleteRequest(_logger, url);
      } else {
        // Check for non-404 errors
        response.ensureSuccessStatusCode();
        _Log.deleteRequestAccepted(_logger, url);
      }
    } on Exception catch (ex, st) {
      _Log.errorSendingDeleteRequest(_logger, url, ex, st);
    }
  }
}
