// ignore_for_file: avoid_classes_with_only_static_members

// Trace       => FINEST
// Debug       => FINE
// Information => INFO
// Warning     => WARNING
// Error       => SEVERE
// Critical    => SEVERE

part of "http_connection.dart";

class Log {
  static void starting(
    Logger logger,
  ) {
    logger.log(
      Level.FINE,
      "Starting HttpConnection.",
    );
  }

  static void skippingStart(
    Logger logger,
  ) {
    logger.log(
      Level.FINE,
      "Skipping start, connection is already started.",
    );
  }

  static void started(
    Logger logger,
  ) {
    logger.log(
      Level.INFO,
      "HttpConnection Started.",
    );
  }

  static void disposingHttpConnection(
    Logger logger,
  ) {
    logger.log(
      Level.FINE,
      "Disposing HttpConnection.",
    );
  }

  static void skippingDispose(
    Logger logger,
  ) {
    logger.log(
      Level.FINE,
      "Skipping dispose, connection is already disposed.",
    );
  }

  static void disposed(
    Logger logger,
  ) {
    logger.log(
      Level.INFO,
      "HttpConnection Disposed.",
    );
  }

  static void startingTransport(
    Logger logger,
    HttpTransportType transportType,
    Uri url,
  ) {
    logger.log(
      Level.FINE,
      "Starting transport $transportType with Url: $url.",
    );
  }

  static void establishingConnection(Logger logger, Uri url) {
    logger.log(
      Level.FINE,
      "Establishing connection with server at $url.",
    );
  }

  static void connectionEstablished(Logger logger, String connectionId) {
    logger.log(
      Level.FINE,
      "Established connection $connectionId with the server.",
    );
  }

  static void errorWithNegotiation(
    Logger logger,
    Uri url,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "Failed to start connection. Error getting negotiation response from $url.",
      exception,
      stackTrace,
    );
  }

  static void errorStartingTransport(
    Logger logger,
    HttpTransportType transport,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "Failed to start connection. Error starting transport $transport.",
      exception,
      stackTrace,
    );
  }

  static void transportNotSupported(Logger logger, String transportName) {
    logger.log(
      Level.FINE,
      "Skipping transport $transportName because it is not supported by this client.",
    );
  }

  static void transportDoesNotSupportTransferFormat(
    Logger logger,
    HttpTransportType transport,
    TransferFormat transferFormat,
  ) {
    logger.log(
      Level.FINE,
      "Skipping transport $transport because it does not support the requested transfer format $transferFormat.",
    );
  }

  static void transportDisabledByClient(
    Logger logger,
    HttpTransportType transport,
  ) {
    logger.log(
      Level.FINE,
      "Skipping transport $transport because it was disabled by the client.",
    );
  }

  static void transportFailed(
    Logger logger,
    HttpTransportType transport,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "Skipping transport $transport because it failed to initialize.",
      exception,
      stackTrace,
    );
  }

  static void webSocketsNotSupportedByOperatingSystem(
    Logger logger,
  ) {
    logger.log(
      Level.FINE,
      "Skipping WebSockets because they are not supported by the operating system.",
    );
  }

  static void transportThrewExceptionOnStop(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "The transport threw an exception while stopping.",
      exception,
      stackTrace,
    );
  }

  static void transportStarted(Logger logger, HttpTransportType transport) {
    logger.log(
      Level.FINE,
      "Transport $transport started.",
    );
  }

  static void serverSentEventsNotSupportedByBrowser(
    Logger logger,
  ) {
    logger.log(
      Level.FINE,
      "Skipping ServerSentEvents because they are not supported by the browser.",
    );
  }

  static void cookiesNotSupported(
    Logger logger,
  ) {
    logger.log(
      Level.FINEST,
      "Cookies are not supported on this platform.",
    );
  }

  static void retryAccessToken(Logger logger, int statusCode) {
    logger.log(
      Level.FINE,
      "$statusCode received, getting a new access token and retrying request.",
    );
  }
}
