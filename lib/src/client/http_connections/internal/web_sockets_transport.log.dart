// ignore_for_file: avoid_classes_with_only_static_members, unused_element, avoid_positional_boolean_parameters

part of "web_sockets_transport.dart";

class _Log {
  static void startTransport(
    Logger logger,
    TransferFormat transferFormat,
    Uri webSocketUrl,
  ) {
    logger.log(
      Level.INFO,
      "Starting transport. Transfer mode: $transferFormat. Url: $webSocketUrl.",
    );
  }

  static void transportStopped(
    Logger logger, [
    Exception? exception,
    StackTrace? stackTrace,
  ]) {
    logger.log(
      Level.FINE,
      'Transport stopped. ${exception != null ? 'Exception: $exception' : ''}, ${stackTrace != null ? 'StackTrace: $stackTrace' : ''}',
    );
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

  static void messageToApp(
    Logger logger,
    int count,
  ) {
    logger.log(
      Level.FINE,
      "Passing message to application. Payload size: $count.",
    );
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

  static void sendStarted(
    Logger logger,
  ) {
    logger.log(Level.FINE, "Starting the send loop.");
  }

  static void sendCanceled(
    Logger logger,
  ) {
    logger.log(Level.FINE, "Send loop canceled.");
  }

  static void sendStopped(
    Logger logger,
  ) {
    logger.log(Level.FINE, "Send loop stopped.");
  }

  static void webSocketClosed(
    Logger logger,
    int? closeStatus,
  ) {
    logger.log(
      Level.INFO,
      "WebSocket closed by the server. Close status: $closeStatus.",
    );
  }

  static void messageReceived(
    Logger logger,
    int count,
    bool endOfMessage,
  ) {
    logger.log(
      Level.FINE,
      "Message received. Size: $count, EndOfMessage: $endOfMessage.",
    );
  }

  static void receivedFromApp(Logger logger, int count) {
    logger.log(
      Level.INFO,
      "Received message from application. Payload size: $count.",
    );
  }

  static void sendMessageCanceled(
    Logger logger,
  ) {
    logger.log(Level.INFO, "Sending a message canceled.");
  }

  static void errorSendingMessage(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.severe(
      "Error while sending a message. Exception: $exception, StackTrace: $stackTrace",
    );
  }

  static void closingWebSocket(
    Logger logger,
  ) {
    logger.log(Level.INFO, "Closing WebSocket.");
  }

  static void closingWebSocketFailed(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "Closing webSocket failed. Exception: $exception, StackTrace: $stackTrace",
    );
  }

  static void cancelMessage(
    Logger logger,
  ) {
    logger.log(Level.FINE, "Canceled passing message to application.");
  }

  static void startedTransport(
    Logger logger,
  ) {
    logger.log(Level.INFO, "Started transport.");
  }

  static void headersNotSupported(
    Logger logger,
  ) {
    logger.log(
      Level.WARNING,
      "Configuring request headers using HttpConnectionOptions.Headers is not supported when using websockets transport on the browser platform.",
    );
  }

  static void receiveErrored(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "Receive loop errored.",
    );
  }

  static void sendErrored(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "Send loop errored.",
    );
  }
}
