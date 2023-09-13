import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:meta/meta.dart";
import "package:os_detect/os_detect.dart" as platform;

import "../../dotnet/connection_context.dart";
import "../../dotnet/i_connection_factory.dart";
import "../../dotnet/invalid_operation_exception.dart";
import "http_connection.dart";
import "http_connection_options.dart";

class HttpConnectionFactory implements IConnectionFactory {
  final HttpConnectionOptions _httpConnectionOptions;
  // final Logger _logger = Logger("HttpConnectionFactory");

  HttpConnectionFactory(HttpConnectionOptions httpConnectionOptions)
      : _httpConnectionOptions = httpConnectionOptions;

  @override
  Future<ConnectionContext> connect(
    Uri endpoint, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    if (_httpConnectionOptions.url != endpoint) {
      throw InvalidOperationException(
        "If {nameof(HttpConnectionOptions)}.{nameof(HttpConnectionOptions.Url)} was set, it must match the {nameof(UriEndPoint)}.{nameof(UriEndPoint.Uri)} passed to {nameof(ConnectAsync)}.",
      );
    }

    // Shallow copy before setting the Url property so we don't mutate the user-defined options object.
    HttpConnectionOptions shallowCopiedOptions =
        shallowCopyHttpConnectionOptions(_httpConnectionOptions)
          ..url = endpoint;

    HttpConnection connection = HttpConnection(shallowCopiedOptions);

    try {
      await connection.start(
        cancellationToken,
      );
      return connection;
    } on Exception catch (_) {
      // Make sure the connection is disposed, in case it allocated any resources before failing.
      await connection.dispose();
      rethrow;
    }
  }

  @visibleForTesting
  static HttpConnectionOptions shallowCopyHttpConnectionOptions(
    HttpConnectionOptions options,
  ) {
    HttpConnectionOptions newOptions = HttpConnectionOptions()
      ..httpMessageHandlerFactory = options.httpMessageHandlerFactory
      ..headers = options.headers
      ..url = options.url
      ..transports = options.transports
      ..skipNegotitation = options.skipNegotitation
      ..accessTokenProvider = options.accessTokenProvider
      ..closeTimeout = options.closeTimeout
      ..defaultTransferFormat = options.defaultTransferFormat
      ..applicationMaxBufferSize = options.applicationMaxBufferSize
      ..transportMaxBufferSize = options.transportMaxBufferSize
      ..useStatefulReconnect = options.useStatefulReconnect;

    if (!platform.isBrowser) {
      newOptions
        ..cookies = options.cookies
        ..clientCertificates = options.clientCertificates
        ..credentials = options.credentials;
      // ..proxy = options.proxy
      // ..useDefaultCredentials = options.useDefaultCredentials
      // ..webSocketConfiguration = options.webSocketConfiguration
      // ..webSocketFactory = options.webSocketFactory;
    }

    return newOptions;
  }
}
