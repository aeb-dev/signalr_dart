import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:logging/logging.dart";
import "package:meta/meta.dart";
import "package:os_detect/os_detect.dart" as platform;
import "package:uri/uri.dart";
import "package:web_socket_channel/status.dart" as status;
import "package:web_socket_channel/web_socket_channel.dart";

import "../../../common/shared/duplex_pipe.dart";
import "../../../dart_web_socket_channel/web_socket_channel_api.dart"
    if (dart.library.io) "../../../dart_web_socket_channel/web_socket_channel_api_io.dart"
    if (dart.library.html) "../../../dart_web_socket_channel/web_socket_channel_api_html.dart"
    as dart_web_socket_channel;
import "../../../dotnet/client_web_socket_options.dart";
import "../../../dotnet/http_version.dart";
import "../../../dotnet/i_duplex_pipe.dart";
import "../../../dotnet/i_stateful_reconnect_feature.dart";
import "../../../dotnet/invalid_operation_exception.dart";
import "../../../dotnet/transfer_format.dart";
import "../http_connection_options.dart";
import "../web_socket_connection_context.dart";
import "constants.dart";
import "i_transport.dart";

part "web_sockets_transport.log.dart";

class WebSocketsTransport implements ITransport, IStatefulReconnectFeature {
  WebSocketChannel? _webSocket;
  final HttpClient? _httpClient;
  IDuplexPipe? _application;
  final Logger _logger = Logger("WebSocketsTransport");
  final Duration _closeTimeout;
  bool _aborted = false;
  final HttpConnectionOptions _httpConnectionOptions;
  late CancellationTokenSource _stopCts;
  bool _useStatefulReconnect;
  bool _gracefulClose = false;

  IDuplexPipe? _transport;

  @internal
  Future<void> running = Future<void>.value();

  @override
  BufferReader get input => _transport!.input;

  @override
  BufferWriter get output => _transport!.output;

  Future<void> Function(BufferWriter writer)? _notifyOnReconnect;

  WebSocketsTransport(
    HttpClient? httpClient,
    HttpConnectionOptions httpConnectionOptions,
    Future<String?> Function()? accessTokenProvider, {
    bool useStatefulReconnect = false,
  })  : _httpClient = httpClient,
        _httpConnectionOptions = httpConnectionOptions,
        _closeTimeout = httpConnectionOptions.closeTimeout,
        _useStatefulReconnect = useStatefulReconnect {
    _httpConnectionOptions.accessTokenProvider = accessTokenProvider;
  }

  @override
  void onReconnected(
    Future<void> Function(BufferWriter writer) notifyOnReconnect,
  ) {
    if (_notifyOnReconnect == null) {
      _notifyOnReconnect = notifyOnReconnect;
    } else {
      Future<void> Function(BufferWriter writer) localNotifyOnReconnect =
          _notifyOnReconnect!;
      _notifyOnReconnect = (BufferWriter writer) async {
        await localNotifyOnReconnect(writer);
        await notifyOnReconnect(writer);
      };
    }
  }

  Future<WebSocketChannel> _defaultWebSocketFactory(
    WebSocketConnectionContext context,
    CancellationToken cancellationToken,
  ) async {
    late WebSocketChannel webSocket;
    UriBuilder uriBuilder = UriBuilder.fromUri(context.uri);

    ClientWebSocketOptions webSocketOptions = ClientWebSocketOptions();

    bool isBrowser = platform.isBrowser;
    if (!isBrowser) {
      webSocketOptions.headers[Constants.userAgent] = Constants.userAgentHeader;
      webSocketOptions.headers["X-Requested-With"] = "XMLHttpRequest";
    }

    if (context.options.headers.isNotEmpty) {
      if (isBrowser) {
        _Log.headersNotSupported(_logger);
      } else {
        webSocketOptions.headers.addAll(context.options.headers);
      }
    }

    // bool allowHttp2 = true;
    bool allowHttp2 = false;

    if (!isBrowser) {
      if (context.options.cookies.isNotEmpty) {
        webSocketOptions.cookies.addAll(context.options.cookies);
      }

      // TODO: create security context for certificates

      if (context.options.clientCertificates.isNotEmpty) {
        // webSocketOptions.clientCertificates
        //     .addAll(context.options.clientCertificates);
      }

      if (context.options.credentials != null) {
        webSocketOptions.credentials = context.options.credentials;
        allowHttp2 = false;
      }

      // TODO: proxy
    }

    context.options.webSocketConfiguration?.call(webSocketOptions);

    // Collect everything under single headers
    Map<String, String> headers = <String, String>{}
      ..addAll(webSocketOptions.headers);

    if (_httpConnectionOptions.accessTokenProvider != null &&
        webSocketOptions.httpVersion.index < HttpVersion.version20.index) {
      // Apply access token logic when using HTTP/1.1 because we don't use the AccessTokenHttpMessageHandler via HttpClient unless the user specifies HTTP/2.0 or higher
      String? accessToken =
          await _httpConnectionOptions.accessTokenProvider?.call();
      if (accessToken != null && accessToken.isNotEmpty) {
        // We can't use request headers in the browser, so instead append the token as a query string in that case
        if (isBrowser) {
          String accessTokenEncoded = Uri.encodeQueryComponent(accessToken);
          uriBuilder.queryParameters["access_token"] = accessTokenEncoded;
        } else {
          headers["Authorization"] = "Bearer $accessToken";
        }
      }
    }

    if (webSocketOptions.cookies.isNotEmpty) {
      headers[HttpHeaders.cookieHeader] = webSocketOptions.cookies.join(";");
    }

    if (webSocketOptions.credentials != null) {
      String? headerValue = headers[HttpHeaders.authorizationHeader];
      if (headerValue == null) {
        headers[HttpHeaders.authorizationHeader] =
            webSocketOptions.credentials!.encodedValue();
      }
    }

    // TODO: create security context for certificates

    // TODO: proxy

    if (!allowHttp2 &&
        webSocketOptions.httpVersion.index >= HttpVersion.version20.index) {
      throw InvalidOperationException(
        "Negotiate Authentication doesn't work with HTTP/2 or higher.",
      );
    }

    try {
      webSocket = dart_web_socket_channel.connect(
        uriBuilder.build(),
        headers: headers,
        httpClient: _httpClient,
        // protocols:
      );

      await webSocket.ready;
    } on Exception catch (_) {
      rethrow;
    }

    return webSocket;
  }

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

    Uri resolvedUrl = _resolveWebSocketsUrl(url);

    _Log.startTransport(_logger, transferFormat, resolvedUrl);

    WebSocketConnectionContext context = WebSocketConnectionContext(
      resolvedUrl,
      _httpConnectionOptions,
    );
    Future<WebSocketChannel> Function(
      WebSocketConnectionContext,
      CancellationToken,
    ) factory =
        _httpConnectionOptions.webSocketFactory ?? _defaultWebSocketFactory;
    _webSocket = await factory(context, cancellationToken);

    if (_webSocket == null) {
      throw InvalidOperationException(
        "Configured WebSocketFactory did not return a value.",
      );
    }

    _Log.startedTransport(_logger);

    _stopCts = CancellationTokenSource();

    bool isReconnect = false;

    if (_transport == null) {
      // Create the pipe pair (Application's writer is connected to Transport's reader, and vice versa)
      var (
        IDuplexPipe transport,
        IDuplexPipe application,
      ) = DuplexPipe.createConnectionPair();

      _transport = transport;
      _application = application;
    } else {
      isReconnect = true;
    }

    // TODO: Handle TCP connection errors
    // https://github.com/SignalR/SignalR/blob/1fba14fa3437e24c204dfaf8a18db3fce8acad3c/src/Microsoft.AspNet.SignalR.Core/Owin/WebSockets/WebSocketHandler.cs#L248-L251
    running = _processSocket(_webSocket!, url, isReconnect);
  }

  Future<void> _processSocket(
    WebSocketChannel socket,
    Uri url,
    bool isReconnect,
  ) async {
    // Begin sending and receiving.
    bool isReceiving = false;
    Future<void> receiving =
        _startReceiving(socket).whenComplete(() => isReceiving = true);
    Future<void> sending = _startSending(socket, isReconnect)
        .whenComplete(() => isReceiving = false);

    if (isReconnect) {
      await _notifyOnReconnect!.call(_transport!.output);
    }

    // Wait for send or receive to complete
    await Future.any<void>(<Future<void>>[receiving, sending]);

    _stopCts.cancelAfter(duration: _closeTimeout);

    if (isReceiving) {
      // We're waiting for the application to finish and there are 2 things it could be doing
      // 1. Waiting for application data
      // 2. Waiting for a websocket send to complete

      // Cancel the application so that ReadAsync yields
      _application!.input.cancelPendingRead();

      await Future.any(
        <Future<void>>[
          sending,
          Future<void>.delayed(_closeTimeout),
        ],
      );

      if (!isReceiving) {
        _aborted = true;
      }
    } else {
      // We're waiting on the websocket to close and there are 2 things it could be doing
      // 1. Waiting for websocket data
      // 2. Waiting on a flush to complete (backpressure being applied)

      _aborted = true;

      // Cancel any pending flush so that we can quit
    }

    await socket.sink.close();

    if (_useStatefulReconnect && !_gracefulClose) {
      bool result = _updateConnectionPair();
      if (!result) {
        return;
      }

      await start(
        url,
        _httpConnectionOptions.defaultTransferFormat,
      );
    }
  }

  Future<void> _startReceiving(WebSocketChannel socket) async {
    BufferReader reader = BufferReader(socket.stream);
    try {
      while (true) {
        ReadResult receiveResult = await reader.read(_stopCts.token);
        Uint8List buffer = receiveResult.buffer.sublist(0);
        try {
          if (socket.closeCode != null) {
            _Log.webSocketClosed(_logger, socket.closeCode);

            if (socket.closeCode != status.normalClosure) {
              throw InvalidOperationException(
                "Websocket closed with error: ${socket.closeCode}.",
              );
            } else {
              _gracefulClose = true;
            }

            return;
          }

          _application!.output.add(buffer);

          _Log.messageReceived(
            _logger,
            buffer.length,
            receiveResult.isCompleted,
          );
        } finally {
          reader.advanceTo(buffer.length);
        }
      }
    } on OperationCancelledException catch (_) {
      _Log.receiveCanceled(_logger);
    } on Exception catch (ex, st) {
      if (!_aborted) {
        if (_gracefulClose) {
          await _application!.output.complete(ex, st);
        } else {
          // only logging in this case because the other case gets the exception flowed to application code
          _Log.receiveErrored(_logger, ex, st);
        }
      }
    } finally {
      // We're done writing
      if (_gracefulClose) {
        await _application!.output.complete();
        await reader.dispose();
      }

      _Log.receiveStopped(_logger);
    }
  }

  Future<void> _startSending(
    WebSocketChannel socket,
    bool isReconnect,
  ) async {
    Exception? error;
    StackTrace? stackTrace;

    bool ignoreFirstCanceled = isReconnect;
    try {
      while (true) {
        ReadResult result = await _application!.input.read();
        Uint8List buffer = result.buffer.sublist(0);

        // Get a frame from the application
        try {
          if (result.isCancelled && !ignoreFirstCanceled) {
            _logger.info("send cancelled");
            break;
          }

          ignoreFirstCanceled = false;

          if (buffer.isNotEmpty) {
            try {
              _Log.receivedFromApp(_logger, buffer.length);

              if (_webSocketCanSend(socket)) {
                socket.sink.add(buffer);
              } else {
                break;
              }
            } on Exception catch (ex, st) {
              if (!_aborted) {
                _Log.errorSendingMessage(_logger, ex, st);
              }
              break;
            }
          } else if (result.isCompleted) {
            break;
          }
        } finally {
          _application!.input.advanceTo(buffer.length);
        }
      }
    } on Exception catch (ex, st) {
      error = ex;
      stackTrace = st;
    } finally {
      if (_webSocketCanSend(socket)) {
        try {
          // We're done sending, send the close frame to the client if the websocket is still open
          await socket.sink.close(
            error != null ? status.internalServerError : status.normalClosure,
            "",
          );
        } on Exception catch (ex, st) {
          _Log.closingWebSocketFailed(_logger, ex, st);
        }
      }

      if (_gracefulClose) {
        _application!.input.complete();
      } else {
        if (error != null) {
          _Log.sendErrored(_logger, error, stackTrace!);
        }
      }

      _Log.sendStopped(_logger);
    }
  }

  static bool _webSocketCanSend(WebSocketChannel ws) => ws.closeCode == null;

  static Uri _resolveWebSocketsUrl(Uri url) {
    if (url.scheme == "http") {
      return url.replace(scheme: "ws");
    } else if (url.scheme == "https") {
      return url.replace(scheme: "wss");
    }

    return url;
  }

  @override
  Future<void> stop() async {
    _gracefulClose = true;
    _Log.transportStopping(_logger);

    if (_application == null) {
      // We never started
      return;
    }

    await _transport!.output.complete();
    _transport!.input.complete();

    // Cancel any pending reads from the application, this should start the entire shutdown process
    _application!.input.cancelPendingRead();

    // Start ungraceful close timer
    _stopCts.cancelAfter(duration: _closeTimeout);

    try {
      await running;
    } on Exception catch (ex, st) {
      _Log.transportStopped(_logger, ex, st);
      // exceptions have been handled in the Running task continuation by closing the channel with the exception
      return;
    } finally {
      await _webSocket?.sink.close();
      _stopCts.dispose();
    }

    _Log.transportStopped(_logger);
  }

  bool _updateConnectionPair() {
    // Lock and check _useStatefulReconnect, we want to swap the Pipe completely before DisableReconnect returns if there is contention there.
    // The calling code will start completing the transport after DisableReconnect
    // so we want to avoid any possibility of the new Pipe staying alive or even worse a new WebSocket connection being open when the transport
    // might think it's closed.
    if (!_useStatefulReconnect) {
      return false;
    }

    var (
      IDuplexPipe transport,
      IDuplexPipe application,
    ) = DuplexPipe.createConnectionPair();

    _application = application;
    _transport = transport;

    return true;
  }

  @override
  void disableReconnect() {
    _useStatefulReconnect = false;
  }
}
