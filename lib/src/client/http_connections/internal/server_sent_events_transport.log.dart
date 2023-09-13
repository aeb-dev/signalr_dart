// ignore_for_file: avoid_classes_with_only_static_members

part of "server_sent_events_transport.dart";

class _Log {
  static void startTransport(Logger logger, TransferFormat transferFormat) {
    logger.log(
      Level.INFO,
      "Starting transport. Transfer mode: $transferFormat",
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

  static void messageToApplication(Logger logger, int count) {
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

  static void eventStreamEnded(
    Logger logger,
  ) {
    logger.log(Level.FINE, "Server-Sent Event Stream ended.");
  }

  static void parsingSSE(Logger logger, int count) {
    logger.log(Level.FINE, "Received $count bytes. Parsing SSE frame.");
  }
}
