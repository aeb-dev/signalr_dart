// ignore_for_file: avoid_classes_with_only_static_members, use_late_for_private_fields_and_variables

part of "long_polling_transport.dart";

class _Log {
  static void startTransport(Logger logger, TransferFormat transferFormat) {
    logger.log(
      Level.INFO,
      "Starting transport. Transfer mode: $transferFormat.",
    );
  }

  static void transportStopped(
    Logger logger, [
    Exception? exception,
    StackTrace? stackTrace,
  ]) {
    logger.log(Level.FINE, "Transport stopped.", exception, stackTrace);
  }

  static void startReceive(
    Logger logger,
  ) {
    logger.log(Level.FINE, "Starting receive loop.");
  }

  static void transportStopping(
    Logger logger,
  ) {
    logger.log(Level.INFO, "Transport is stopping.");
  }

  static void receiveCanceled(
    Logger logger,
  ) {
    logger.log(Level.FINE, "Receive loop canceled.");
  }

  static void receiveStopped(
    Logger logger,
  ) {
    logger.log(Level.FINE, "Receive loop stopped.");
  }

  static void closingConnection(
    Logger logger,
  ) {
    logger.log(Level.FINE, "The server is closing the connection.");
  }

  static void receivedMessages(
    Logger logger,
  ) {
    logger.log(Level.FINE, "Received messages from the server.");
  }

  static void errorPolling(
    Logger logger,
    Uri pollUrl,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "Error while polling $pollUrl.",
      exception,
      stackTrace,
    );
  }

  static void pollResponseReceived(
    Logger logger,
    int statusCode,
    int contentLength,
  ) {
    logger.log(
      Level.SEVERE,
      "Poll response with status code $statusCode received from server. Content length: $contentLength.",
    );
  }

  static void sendingDeleteRequest(Logger logger, Uri pollUrl) {
    logger.log(Level.FINE, "Sending DELETE request to $pollUrl.");
  }

  static void deleteRequestAccepted(Logger logger, Uri pollUrl) {
    logger.log(Level.FINE, "DELETE request to $pollUrl accepted.");
  }

  static void errorSendingDeleteRequest(
    Logger logger,
    Uri pollUrl,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "Error sending DELETE request to $pollUrl.",
      exception,
      stackTrace,
    );
  }

  static void connectionAlreadyClosedSendingDeleteRequest(
    Logger logger,
    Uri pollUrl,
  ) {
    logger.log(
      Level.FINE,
      "A 404 response was returned from sending DELETE request to $pollUrl, likely because the transport was already closed on the server.",
    );
  }
}
