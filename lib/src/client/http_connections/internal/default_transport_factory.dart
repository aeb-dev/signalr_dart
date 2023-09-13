import "dart:io";

import "package:http/http.dart";
import "package:logging/logging.dart";

import "../../../common/http_connections/http_transport_type.dart";
import "../../../dotnet/invalid_operation_exception.dart";
import "../http_connection_options.dart";
import "i_transport.dart";
import "i_transport_factory.dart";
import "long_polling_transport.dart";
import "server_sent_events_transport.dart";
import "web_sockets_transport.dart";

class DefaultTransportFactory implements ITransportFactory {
  final Client? _client;
  final HttpClient? _httpClient;
  final HttpConnectionOptions _httpConnectionOptions;
  final Future<String?> Function()? _accessTokenProvider;
  final HttpTransportType _requestedTransportType;
  final Logger _logger = Logger("DefaultTransportFactory");
  static bool _websocketsSupported = true;

  DefaultTransportFactory(
    HttpTransportType requestedTransportType,
    Client? client,
    HttpClient? httpClient,
    HttpConnectionOptions httpConnectionOptions,
    Future<String?> Function()? accessTokenProvider,
  )   : _requestedTransportType = requestedTransportType,
        _client = client,
        _httpClient = httpClient,
        _httpConnectionOptions = httpConnectionOptions,
        _accessTokenProvider = accessTokenProvider;

  @override
  ITransport createTransport(
    HttpTransportType availableServerTransports, {
    bool useStatefulReconnect = false,
  }) {
    if (_websocketsSupported &&
        (availableServerTransports.value &
                HttpTransportType.webSockets.value &
                _requestedTransportType.value) ==
            HttpTransportType.webSockets.value) {
      try {
        return WebSocketsTransport(
          _httpClient,
          _httpConnectionOptions,
          _accessTokenProvider,
          useStatefulReconnect: useStatefulReconnect,
        );
        // ignore: avoid_catching_errors
      } on UnsupportedError catch (ex, st) {
        _logger.log(
          Level.FINE,
          "Transport '${HttpTransportType.webSockets}' is not supported.",
          ex,
          st,
        );
        _websocketsSupported = false;
      }
    }

    if ((availableServerTransports.value &
            HttpTransportType.serverSentEvents.value &
            _requestedTransportType.value) ==
        HttpTransportType.serverSentEvents.value) {
      // We don't need to give the transport the accessTokenProvider because the HttpClient has a message handler that does the work for us.
      return ServerSentEventsTransport(
        _client!,
        useStatefulReconnect: useStatefulReconnect,
      );
    }

    if ((availableServerTransports.value &
            HttpTransportType.longPolling.value &
            _requestedTransportType.value) ==
        HttpTransportType.longPolling.value) {
      // We don't need to give the transport the accessTokenProvider because the HttpClient has a message handler that does the work for us.
      return LongPollingTransport(
        _client!,
        useStatefulReconnect: useStatefulReconnect,
      );
    }

    throw InvalidOperationException(
      "No requested transports available on the server.",
    );
  }
}
