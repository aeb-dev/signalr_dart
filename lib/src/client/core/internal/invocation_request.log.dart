// ignore_for_file: avoid_classes_with_only_static_members

part of "invocation_request.dart";

class _Log {
  static void invocationCreated(
    Logger logger,
    String invocationId,
  ) =>
      logger.log(Level.FINEST, "Invocation $invocationId created.");
  static void invocationDisposed(
    Logger logger,
    String invocationId,
  ) =>
      logger.log(Level.FINEST, "Invocation $invocationId disposed.");
  static void invocationCompleted(
    Logger logger,
    String invocationId,
  ) =>
      logger.log(Level.FINEST, "Invocation $invocationId marked as completed.");
  static void invocationFailed(
    Logger logger,
    String invocationId,
  ) =>
      logger.log(Level.FINEST, "Invocation $invocationId marked as failed.");

  // Category: Streaming
  static void errorWritingStreamItem(
    Logger logger,
    String invocationId,
    Exception exception,
    StackTrace stackTrace,
  ) =>
      logger.log(
        Level.SEVERE,
        "Invocation $invocationId caused an error trying to write a stream item.",
        exception,
        stackTrace,
      );
  static void receivedUnexpectedComplete(
    Logger logger,
    String invocationId,
  ) =>
      logger.log(
        Level.SEVERE,
        "Invocation $invocationId received a completion result, but was invoked as a streaming invocation.",
      );

  // Category: NonStreaming
  static void streamItemOnNonStreamInvocation(
    Logger logger,
    String invocationId,
  ) =>
      logger.log(
        Level.SEVERE,
        "Invocation $invocationId received stream item but was invoked as a non-streamed invocation.",
      );
}
