import "dart:io";

import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:http/http.dart";
import "package:logging/logging.dart";
import "package:os_detect/os_detect.dart" as platform;
import "package:pool/pool.dart";
import "package:uri/uri.dart";

import "../../common/http_connections/available_transport.dart";
import "../../common/http_connections/http_transport_type.dart";
import "../../common/http_connections/negotiate_protocol.dart";
import "../../common/http_connections/negotiation_response.dart";
import "../../dart_http/http_api.dart"
    if (dart.library.io) "../../dart_http/http_api_io.dart"
    if (dart.library.html) "../../dart_http/http_api_html.dart" as dart_http;
import "../../dotnet/connection_context.dart";
import "../../dotnet/i_duplex_pipe.dart";
import "../../dotnet/i_stateful_reconnect_feature.dart";
import "../../dotnet/invalid_operation_exception.dart";
import "../../dotnet/transfer_format.dart";
import "../../extensions/base_response.dart";
import "http_connection_options.dart";
import "http_request_message.dart";
import "internal/access_token_http_message_handler.dart";
import "internal/default_transport_factory.dart";
import "internal/i_transport.dart";
import "internal/i_transport_factory.dart";
import "internal/logging_http_message_handler.dart";
import "no_transport_supported_exception.dart";
import "transport_failed_expection.dart";

part "http_connection.log.dart";

class HttpConnection implements ConnectionContext {
  static const int _maxRedirects = 100;
  static const int _protocolVersionNumber = 1;
  static final Future<String?> _noAccessToken = Future<String?>.value();

  final Logger logger = Logger("HttpConnection");

  final Pool _connectionLock = Pool(1);
  bool _started = false;
  bool _disposed = false;

  @override
  bool hasInherentKeepAlive = false;

  @override
  bool useStatefulReconnect = false;

  Client? _client;
  HttpClient? _httpClient;

  final HttpConnectionOptions _httpConnectionOptions;
  ITransport? _transport;
  late ITransportFactory _transportFactory;
  String? _connectionId;
  final Uri _url;
  Future<String?> Function()? _accessTokenProvider;

  @override
  IDuplexPipe get transport {
    _checkDisposed();
    if (_transport == null) {
      throw InvalidOperationException(
        "Cannot access the {nameof(Transport)} pipe before the connection has started.",
      );
    }

    return _transport!;
  }

  @override
  String? get connectionId => _connectionId;

  Map<Object, Object?> items = <Object, Object?>{};

  HttpConnection(
    HttpConnectionOptions httpConnectionOptions,
  )   : _httpConnectionOptions = httpConnectionOptions,
        _url = httpConnectionOptions.url {
    httpConnectionOptions.url = _url;

    if (!_httpConnectionOptions.skipNegotitation ||
        _httpConnectionOptions.transports != HttpTransportType.webSockets) {
      _client = _createHttpClient();
    }

    _transportFactory = DefaultTransportFactory(
      httpConnectionOptions.transports,
      _client,
      _httpClient,
      httpConnectionOptions,
      getAccessToken,
    );
  }

  Future<void> start([
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    await _startCore(
      _httpConnectionOptions.defaultTransferFormat,
      cancellationToken,
    );
  }

  Future<void> _startCore([
    TransferFormat transferFormat = TransferFormat.binary,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    _checkDisposed();

    if (_started) {
      Log.skippingStart(logger);
      return;
    }

    // PoolResource pr = await _connectionLock.request(cancellationToken);
    PoolResource pr = await _connectionLock.request();
    try {
      _checkDisposed();
      if (_started) {
        Log.skippingStart(logger);
        return;
      }

      Log.starting(logger);

      await _selectAndStartTrasport(transferFormat, cancellationToken);

      _started = true;
      Log.started(logger);
    } finally {
      pr.release();
    }
  }

  @override
  Future<void> dispose() async {
    await _disposeCore();
  }

  Future<void> _disposeCore() async {
    if (_disposed) {
      return;
    }

    PoolResource pr = await _connectionLock.request();
    try {
      if (!_disposed && _started) {
        Log.disposingHttpConnection(logger);

        // Stop the transport, but we don't care if it throws.
        // The transport should also have completed the pipe with this exception.
        try {
          await _transport!.stop();
        } on Exception catch (ex, st) {
          Log.transportThrewExceptionOnStop(logger, ex, st);
        }

        Log.disposed(logger);
      } else {
        Log.skippingDispose(logger);
      }

      _client?.close();
    } finally {
      // We want to do these things even if the WaitForWriterToComplete/WaitForReaderToComplete fails
      if (!_disposed) {
        _disposed = true;
      }

      pr.release();
    }
  }

  Future<void> _selectAndStartTrasport(
    TransferFormat transferFormat,
    CancellationToken cancellationToken,
  ) async {
    Uri uri = _url;
    // Set the initial access token provider back to the original one from options
    _accessTokenProvider = _httpConnectionOptions.accessTokenProvider;
    List<Exception> transportExceptions = List<Exception>.empty(growable: true);

    if (_httpConnectionOptions.skipNegotitation) {
      if (_httpConnectionOptions.transports == HttpTransportType.webSockets) {
        Log.startingTransport(
          logger,
          _httpConnectionOptions.transports,
          uri,
        );
        await _startTransport(
          uri,
          _httpConnectionOptions.transports,
          transferFormat,
          cancellationToken,
          useStatefulReconnect: false,
        );
      } else {
        throw InvalidOperationException(
          "Negotiation can only be skipped when using the WebSocket transport directly.",
        );
      }
    } else {
      NegotiationResponse? negotiationResponse;
      int redirects = 0;
      do {
        negotiationResponse =
            await _getNegotiationResponse(uri, cancellationToken);
        if (negotiationResponse.url != null) {
          uri = Uri.parse(negotiationResponse.url!);
        }

        if (negotiationResponse.accessToken != null) {
          String accessToken = negotiationResponse.accessToken!;
          _accessTokenProvider = () => Future<String?>.value(accessToken);
        }

        ++redirects;
      } while (negotiationResponse.url != null && redirects < _maxRedirects);

      if (redirects == _maxRedirects && negotiationResponse.url != null) {
        throw InvalidOperationException(
          "Negotiate redirection limit exceeded.",
        );
      }

      // This should only need to happen once
      Uri connectUrl =
          _createConnectUrl(uri, negotiationResponse.connectionToken);

      // We're going to search for the transfer format as a string because we don't want to parse
      // all the transfer formats in the negotiation response, and we want to allow transfer formats
      // we don't understand in the negotiate response.
      String transferFormatString = transferFormat.toString();

      for (AvailableTransport transport
          in negotiationResponse.availableTransports!) {
        HttpTransportType? transportType =
            HttpTransportType.tryParse(transport.transport!);

        if (transportType == null) {
          Log.transportNotSupported(logger, transport.transport!);
          transportExceptions.add(
            TransportFailedException(
              transport.transport!,
              "The transport is not supported by the client.",
            ),
          );
          continue;
        }

        try {
          if ((transportType.value & _httpConnectionOptions.transports.value) ==
              0) {
            Log.transportDisabledByClient(logger, transportType);
            transportExceptions.add(
              TransportFailedException(
                transportType.toString(),
                "The transport is disabled by the client.",
              ),
            );
          } else if (!transport.transferFormats!
              .contains(transferFormatString)) {
            Log.transportDoesNotSupportTransferFormat(
              logger,
              transportType,
              transferFormat,
            );
            transportExceptions.add(
              TransportFailedException(
                transportType.toString(),
                "The transport does not support the '$transferFormat' transfer format.",
              ),
            );
          } else {
            // The negotiation response gets cleared in the fallback scenario.
            if (negotiationResponse == null) {
              // Temporary until other transports work
              _httpConnectionOptions.useStatefulReconnect =
                  transportType == HttpTransportType.webSockets
                      ? _httpConnectionOptions.useStatefulReconnect
                      : false;
              negotiationResponse =
                  await _getNegotiationResponse(uri, cancellationToken);
              connectUrl =
                  _createConnectUrl(uri, negotiationResponse.connectionToken);
            }

            Log.startingTransport(logger, transportType, uri);
            await _startTransport(
              connectUrl,
              transportType,
              transferFormat,
              cancellationToken,
              useStatefulReconnect: negotiationResponse.useStatefulReconnect,
            );
            break;
          }
        } on Exception catch (ex, st) {
          Log.transportFailed(logger, transportType, ex, st);

          transportExceptions.add(
            TransportFailedException(
              transportType.toString(),
              ex.toString(),
            ),
          );

          // Try the next transport
          // Clear the negotiation response so we know to re-negotiate.
          negotiationResponse = null;
        }
      }
    }

    if (_transport == null) {
      if (transportExceptions.isNotEmpty) {
        throw AggregateException(
          // "Unable to connect to the server with any of the available transports.",
          transportExceptions,
        );
      } else {
        throw NoTransportSupportedException(
          "None of the transports supported by the client are supported by the server.",
        );
      }
    }
  }

  Future<NegotiationResponse> _negotiate(
    Uri url,
    Client httpClient,
    CancellationToken cancellationToken,
  ) async {
    try {
      Log.establishingConnection(logger, url);
      UriBuilder urlBuilder = UriBuilder.fromUri(url);
      if (!url.path.endsWith("/")) {
        urlBuilder.path += "/";
      }
      urlBuilder.path += "negotiate";
      if (!urlBuilder.queryParameters.containsKey("negotiateVersion")) {
        urlBuilder.queryParameters["negotiateVersion"] =
            _protocolVersionNumber.toString();
      }

      if (_httpConnectionOptions.useStatefulReconnect) {
        urlBuilder.queryParameters["useAck"] = "true";
      }

      if (urlBuilder.scheme == "ws") {
        urlBuilder.scheme = "http";
      } else if (url.scheme == "wss") {
        urlBuilder.scheme = "https";
      }

      Uri uri = urlBuilder.build();

      HttpRequestMessage request = HttpRequestMessage("POST", uri);
      request.options["isNegotiation"] = true;

      // ResponseHeadersRead instructs SendAsync to return once headers are read
      // rather than buffer the entire response. This gives a small perf boost.
      // Note that it is important to dispose of the response when doing this to
      // avoid leaving the connection open.

      StreamedResponse response =
          // await httpClient.send(request, cancellationToken);
          await httpClient.send(request);

      response.ensureSuccessStatusCode();

      NegotiationResponse negotiationResponse =
          NegotiateProtocol.parseResponse(await response.stream.toBytes());
      if (negotiationResponse.error != null) {
        throw InvalidOperationException(negotiationResponse.error!);
      }

      Log.connectionEstablished(
        logger,
        negotiationResponse.connectionId!,
      );
      return negotiationResponse;
    } on Exception catch (ex, st) {
      Log.errorWithNegotiation(logger, url, ex, st);
      rethrow;
    }
  }

  static Uri _createConnectUrl(Uri url, String? connectionId) {
    if (connectionId == null || connectionId.isEmpty) {
      throw const FormatException("Invalid connection id.");
    }

    UriBuilder uriBuilder = UriBuilder.fromUri(url);
    uriBuilder.queryParameters["id"] = connectionId;

    return uriBuilder.build();
  }

  Future<void> _startTransport(
    Uri connectUrl,
    HttpTransportType transportType,
    TransferFormat transferFormat,
    CancellationToken cancellationToken, {
    required bool useStatefulReconnect,
  }) async {
    // Construct the transport
    ITransport transport = _transportFactory.createTransport(
      transportType,
      useStatefulReconnect: useStatefulReconnect,
    );

    // Start the transport, giving it one end of the pipe
    try {
      await transport.start(connectUrl, transferFormat, cancellationToken);
    } on Exception catch (ex, st) {
      Log.errorStartingTransport(logger, transportType, ex, st);

      _transport = null;
      rethrow;
    }

    // // Disable keep alives for long polling
    hasInherentKeepAlive = transportType == HttpTransportType.longPolling;

    // We successfully started, set the transport properties (we don't want to set these until the transport is definitely running).
    _transport = transport;

    if (useStatefulReconnect && _transport is IStatefulReconnectFeature) {
      this.useStatefulReconnect = useStatefulReconnect;
    }
    Log.transportStarted(logger, transportType);
  }

  Client _createHttpClient() {
    Client client;

    bool isBrowser = platform.isBrowser;
    // bool allowHttp2 = false;

    if (!isBrowser) {
      SecurityContext securityContext = SecurityContext(withTrustedRoots: true);

      // TODO: proxy
      // Configure options that do not work in the browser inside this if-block
      // if (_httpConnectionOptions.proxy != null) {
      //   httpClient.findProxy = (_) => _httpConnectionOptions.proxy!;
      // }

      for (List<int> cert in _httpConnectionOptions.clientCertificates) {
        securityContext.setTrustedCertificatesBytes(cert);
      }

      // if (_httpConnectionOptions.credentials != null) {
      //   httpClientHandler.credentials = _httpConnectionOptions.credentials;
      //   // Negotiate Auth isn't supported over HTTP/2 and HttpClient does not gracefully fallback to HTTP/1.1 in that case
      //   // https://github.com/dotnet/runtime/issues/1582
      //   allowHttp2 = false;
      // }

      _httpClient = HttpClient(context: securityContext);
    }

    client = dart_http.createClient(_httpClient);

    if (_httpConnectionOptions.httpMessageHandlerFactory != null) {
      client = _httpConnectionOptions.httpMessageHandlerFactory!.call(client);
    }

    // Apply the authorization header in a handler instead of a default header because it can change with each request
    client = AccessTokenHttpMessageHandler(
      this,
      client,
      _httpConnectionOptions,
    );

    client = LoggingHttpMessageHandler(client, _httpConnectionOptions);
    // if (allowHttp2) {
    //   client = Http2HttpMessageHandler(client);
    // }

    // bool userSetUserAgent = false;
    // Apply any headers configured on the HttpConnectionOptions
    // for (MapEntry<String, String> kv
    //     in _httpConnectionOptions.headers.entries) {
    //   // Check if the key is User-Agent and remove if empty string then replace if it exists.
    //   if (kv.key == Constants.userAgent) {
    //     userSetUserAgent = true;
    //     if (kv.value.isEmpty) {
    //       client.headers.remove(kv.key);
    //       httpClient.DefaultRequestHeaders.Remove(header.Key);
    //     } else if (httpClient.DefaultRequestHeaders.Contains(header.Key)) {
    //       httpClient.DefaultRequestHeaders.Remove(header.Key);
    //       httpClient.DefaultRequestHeaders.Add(header.Key, header.Value);
    //     } else {
    //       httpClient.DefaultRequestHeaders.Add(header.Key, header.Value);
    //     }
    //   } else {
    //     client.defaultRequestHeaders.Add(header.Key, header.Value);
    //   }
    // }

    // Apply default user agent only if user hasn't specified one (empty or not)
    // Don't pre-emptively set this, some frameworks (mono) have different user agent format rules,
    // so allowing a user to set an empty one avoids throwing on those frameworks.
    // if (!userSetUserAgent) {
    //   httpClient.DefaultRequestHeaders.Add(
    //     Constants.userAgent,
    //     Constants.userAgentHeader,
    //   );
    // }

    // httpClient.DefaultRequestHeaders.Remove("X-Requested-With");
    // // Tell auth middleware to 401 instead of redirecting
    // httpClient.DefaultRequestHeaders.Add("X-Requested-With", "XMLHttpRequest");

    return client;
  }

  Future<String?> getAccessToken() {
    if (_accessTokenProvider == null) {
      return _noAccessToken;
    }

    return _accessTokenProvider!.call();
  }

  void _checkDisposed() {
    if (_disposed) {
      throw const ObjectDisposedException();
    }
  }

  Future<NegotiationResponse> _getNegotiationResponse(
    Uri uri,
    CancellationToken cancellationToken,
  ) async {
    NegotiationResponse negotiationResponse = await _negotiate(
      uri,
      _client!,
      cancellationToken,
    );
    // If the negotiationVersion is greater than zero then we know that the negotiation response contains a
    // connectionToken that will be required to conenct. Otherwise we just set the connectionId and the
    // connectionToken on the client to the same value.
    _connectionId = negotiationResponse.connectionId;
    if (negotiationResponse.version == 0) {
      negotiationResponse.connectionToken = _connectionId;
    }

    return negotiationResponse;
  }
}
