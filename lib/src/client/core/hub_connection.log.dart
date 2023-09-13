// ignore_for_file: avoid_classes_with_only_static_members, unused_element

part of "hub_connection.dart";

class _Log {
  static void preparingNonBlockingInvocation(
    Logger logger,
    String target,
    int argumentCount,
  ) =>
      logger.log(
        Level.FINEST,
        "Preparing non-blocking invocation of '$target', with $argumentCount argument(s).",
      );

  static void preparingBlockingInvocation(
    Logger logger,
    String invocationId,
    String target,
    String returnType,
    int argumentCount,
  ) =>
      logger.log(
        Level.FINEST,
        "Preparing blocking invocation '$invocationId' of '$target', with return type '$returnType' and $argumentCount argument(s).",
      );

  static void registeringInvocation(
    Logger logger,
    String invocationId,
  ) =>
      logger.log(
        Level.FINE,
        "Registering Invocation ID '$invocationId' for tracking.",
      );

  static void issuingInvocation(
    Logger logger,
    String invocationId,
    String returnType,
    String methodName,
    List<Object?> args,
  ) {
    String argsList =
        args.map((Object? a) => a?.runtimeType ?? "(null)").join(", ");
    logger.log(
      Level.FINEST,
      "Issuing Invocation '$invocationId': $returnType $methodName($argsList).",
    );
  }

  static void sendingMessage(
    Logger logger,
    HubMessage message,
  ) {
    if (message is HubInvocationMessage) {
      logger.log(
        Level.FINE,
        "Sending ${message.runtimeType} message '${message.invocationId}'.",
      );
    } else {
      logger.log(
        Level.FINE,
        "Sending ${message.runtimeType} message.",
      );
    }
  }

  static void messageSent(
    Logger logger,
    HubMessage message,
  ) {
    if (message is HubInvocationMessage) {
      logger.log(
        Level.FINE,
        "Sending ${message.runtimeType} message '${message.invocationId}' completed.",
      );
    } else {
      logger.log(
        Level.FINE,
        "Sending ${message.runtimeType} message completed.",
      );
    }
  }

  static void failedToSendInvocation(
    Logger logger,
    String invocationId,
    Exception exception,
    StackTrace stackTrace,
  ) =>
      logger.log(
        Level.SEVERE,
        "Sending Invocation '$invocationId' failed.",
        exception,
        stackTrace,
      );

  static void receivedInvocation(
    Logger logger,
    String? invocationId,
    String methodName,
    List<Object?> args,
  ) {
    String argsList =
        args.map((Object? a) => a?.runtimeType ?? "(null)").join(", ");
    logger.log(
      Level.FINEST,
      "Received Invocation '$invocationId': $methodName($argsList).",
    );
  }

  static void droppedCompletionMessage(
    Logger logger,
    String invocationId,
  ) =>
      logger.log(
        Level.WARNING,
        "Dropped unsolicited Completion message for invocation '$invocationId'.",
      );

  static void droppedStreamMessage(
    Logger logger,
    String invocationId,
  ) =>
      logger.log(
        Level.WARNING,
        "Dropped unsolicited StreamItem message for invocation '$invocationId'.",
      );

  static void shutdownConnection(
    Logger logger,
  ) =>
      logger.log(
        Level.FINEST,
        "Shutting down connection.",
      );

  static void shutdownWithError(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) =>
      logger.log(
        Level.SEVERE,
        "Connection is shutting down due to an error.",
        exception,
        stackTrace,
      );

  static void removingInvocation(
    Logger logger,
    String invocationId,
  ) =>
      logger.log(
        Level.FINEST,
        "Removing pending invocation $invocationId.",
      );

  static void missingHandler(
    Logger logger,
    String target,
  ) {
    logger.log(
      Level.WARNING,
      "Failed to find handler for '$target' method.",
    );
  }

  static void receivedStreamItem(
    Logger logger,
    String invocationId,
  ) {
    logger.log(
      Level.FINEST,
      "Received StreamItem for Invocation $invocationId.",
    );
  }

  static void cancellingStreamItem(
    Logger logger,
    String invocationId,
  ) {
    logger.log(
      Level.FINEST,
      "Cancelling dispatch of StreamItem message for Invocation $invocationId. The invocation was canceled.",
    );
  }

  static void receivedStreamItemAfterClose(
    Logger logger,
    String invocationId,
  ) {
    logger.log(
      Level.WARNING,
      "Invocation $invocationId received stream item after channel was closed.",
    );
  }

  static void receivedInvocationCompletion(
    Logger logger,
    String invocationId,
  ) {
    logger.log(
      Level.FINEST,
      "Received Completion for Invocation $invocationId.",
    );
  }

  static void cancellingInvocationCompletion(
    Logger logger,
    String invocationId,
  ) {
    logger.log(
      Level.FINEST,
      "Cancelling dispatch of Completion message for Invocation $invocationId. The invocation was cancelled.",
    );
  }

  static void stopped(Logger logger) {
    logger.log(
      Level.FINE,
      "HubConnection stopped.",
    );
  }

  static void invocationAlreadyInUse(
    Logger logger,
    String invocationId,
  ) {
    logger.log(
      Level.SEVERE,
      "Invocation ID '$invocationId' is already in use.",
    );
  }

  static void receivedUnexpectedResponse(
    Logger logger,
    String invocationId,
  ) {
    logger.log(
      Level.SEVERE,
      "Unsolicited response received for invocation '$invocationId'.",
    );
  }

  static void hubProtocol(
    Logger logger,
    String protocol,
    int version,
  ) {
    logger.log(
      Level.INFO,
      "Using HubProtocol '$protocol v$version'.",
    );
  }

  static void preparingStreamingInvocation(
    Logger logger,
    String invocationId,
    String target,
    String returnType,
    int argumentCount,
  ) {
    logger.log(
      Level.FINEST,
      "Preparing streaming invocation '$invocationId' of '$target', with return type '$returnType' and $argumentCount argument(s).",
    );
  }

  static void resettingKeepAliveTimer(Logger logger) {
    logger.log(
      Level.FINEST,
      "Resetting keep-alive timer, received a message from the server.",
    );
  }

  static void errorDuringClosedEvent(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "An exception was thrown in the handler for the Closed event.",
      exception,
      stackTrace,
    );
  }

  static void sendingHubHandshake(Logger logger) {
    logger.log(
      Level.FINE,
      "Sending Hub Handshake.",
    );
  }

  static void receivedPing(Logger logger) {
    logger.log(
      Level.FINEST,
      "Received a ping message.",
    );
  }

  static void errorInvokingClientSideMethod(
    Logger logger,
    String methodName,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "Invoking client side method '$methodName' failed.",
      exception,
      stackTrace,
    );
  }

  static void errorReceivingHandshakeResponse(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "The underlying connection closed while processing the handshake response. See exception for details.",
      exception,
      stackTrace,
    );
  }

  static void handshakeServerError(Logger logger, String error) {
    logger.log(Level.SEVERE, "Server returned handshake error: $error");
  }

  static void receivedClose(Logger logger) {
    logger.log(
      Level.FINE,
      "Received close message.",
    );
  }

  static void receivedCloseWithError(Logger logger, String error) {
    logger.log(Level.SEVERE, "Received close message with an error: $error");
  }

  static void handshakeComplete(Logger logger) {
    logger.log(
      Level.FINE,
      "Handshake with server complete.",
    );
  }

  static void registeringHandler(Logger logger, String methodName) {
    logger.log(
      Level.FINE,
      "Registering handler for client method '$methodName'.",
    );
  }

  static void removingHandlers(Logger logger, String methodName) {
    logger.log(
      Level.FINE,
      "Removing handlers for client method '$methodName'.",
    );
  }

  static void starting(Logger logger) {
    logger.log(
      Level.FINE,
      "Starting HubConnection.",
    );
  }

  static void errorStartingConnection(
    Logger logger,
    Exception ex,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "Error starting connection.",
      ex,
      stackTrace,
    );
  }

  static void started(Logger logger) {
    logger.log(
      Level.INFO,
      "HubConnection started.",
    );
  }

  static void sendingCancellation(Logger logger, String invocationId) {
    logger.log(
      Level.FINE,
      "Sending Cancellation for Invocation '$invocationId'.",
    );
  }

  static void cancellingOutstandingInvocations(Logger logger) {
    logger.log(
      Level.FINE,
      "Canceling all outstanding invocations.",
    );
  }

  static void receiveLoopStarting(Logger logger) {
    logger.log(
      Level.FINE,
      "Receive loop starting.",
    );
  }

  static void startingServerTimeoutTimer(
    Logger logger,
    Duration serverTimeout,
  ) =>
      logger.log(
        Level.FINE,
        "Starting server timeout timer. Duration: ${serverTimeout.inMilliseconds.toStringAsFixed(2)}ms",
      );

  static void notUsingServerTimeout(Logger logger) {
    logger.log(
      Level.FINE,
      "Not using server timeout because the transport inherently tracks server availability.",
    );
  }

  static void serverDisconnectedWithError(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "The server connection was terminated with an error.",
      exception,
      stackTrace,
    );
  }

  static void invokingClosedEventHandler(Logger logger) {
    logger.log(
      Level.FINE,
      "Invoking the Closed event handler.",
    );
  }

  static void stopping(Logger logger) {
    logger.log(
      Level.FINE,
      "Stopping HubConnection.",
    );
  }

  static void terminatingReceiveLoop(Logger logger) {
    logger.log(
      Level.FINE,
      "Terminating receive loop.",
    );
  }

  static void waitingForReceiveLoopToTerminate(Logger logger) {
    logger.log(
      Level.FINE,
      "Waiting for the receive loop to terminate.",
    );
  }

  static void processingMessage(Logger logger, int messageLength) {
    logger.log(
      Level.FINEST,
      "Processing $messageLength byte message from server.",
    );
  }

  static void waitingOnConnectionLock(
    Logger logger,
    String? methodName,
  ) {
    logger.log(
      Level.FINEST,
      "Waiting on Connection Lock in $methodName.",
    );
  }

  static void releasingConnectionLock(
    Logger logger,
    String? methodName,
  ) {
    logger.log(
      Level.FINEST,
      "Releasing Connection Lock in $methodName.",
    );
  }

  static void unableToSendCancellation(
    Logger logger,
    String invocationId,
  ) {
    logger.log(
      Level.FINEST,
      "Unable to send cancellation for invocation '$invocationId'. The connection is inactive.",
    );
  }

  static void argumentBindingFailure(
    Logger logger,
    String? invocationId,
    String methodName,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "Failed to bind arguments received in invocation '$invocationId' of '$methodName'.",
      exception,
      stackTrace,
    );
  }

  static void acquiredConnectionLockForPing(Logger logger) {
    logger.log(
      Level.FINEST,
      "Acquired the Connection Lock in order to ping the server.",
    );
  }

  static void unableToAcquireConnectionLockForPing(Logger logger) {
    logger.log(
      Level.FINEST,
      "Skipping ping because a send is already in progress.",
    );
  }

  static void startingStream(
    Logger logger,
    String streamId,
  ) {
    logger.log(
      Level.FINEST,
      "Initiating stream '$streamId'.",
    );
  }

  static void sendingStreamItem(
    Logger logger,
    String streamId,
  ) {
    logger.log(
      Level.FINEST,
      "Sending item for stream '$streamId'.",
    );
  }

  static void cancellingStream(
    Logger logger,
    String streamId,
  ) {
    logger.log(
      Level.FINEST,
      "Stream '$streamId' has been canceled by client.",
    );
  }

  static void completingStream(
    Logger logger,
    String streamId,
  ) {
    logger.log(
      Level.FINEST,
      "Sending completion message for stream '$streamId'.",
    );
  }

  static void stateTransitionFailed(
    Logger logger,
    HubConnectionState expectedState,
    HubConnectionState newState,
    HubConnectionState actualState,
  ) {
    logger.log(
      Level.FINE,
      "The HubConnection failed to transition from the $expectedState state to the $newState state because it was actually in the $actualState state.",
    );
  }

  static void reconnecting(Logger logger) {
    logger.log(
      Level.INFO,
      "HubConnection reconnecting.",
    );
  }

  static void reconnectingWithError(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "HubConnection reconnecting due to an error.",
      exception,
      stackTrace,
    );
  }

  static void reconnected(
    Logger logger,
    int reconnectAttempts,
    Duration elapsedTime,
  ) {
    logger.log(
      Level.INFO,
      "HubConnection reconnected successfully after $reconnectAttempts attempts and $elapsedTime elapsed.",
    );
  }

  static void reconnectAttemptsExhausted(
    Logger logger,
    int reconnectAttempts,
    Duration elapsedTime,
  ) {
    logger.log(
      Level.INFO,
      "Reconnect retries have been exhausted after $reconnectAttempts failed attempts and $elapsedTime elapsed. Disconnecting.",
    );
  }

  static void awaitingReconnectRetryDelay(
    Logger logger,
    int reconnectAttempts,
    Duration retryDelay,
  ) {
    logger.log(
      Level.FINEST,
      "Reconnect attempt number $reconnectAttempts will start in $retryDelay.",
    );
  }

  static void reconnectAttemptFailed(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINEST,
      "Reconnect attempt failed.",
      exception,
      stackTrace,
    );
  }

  static void errorDuringReconnectingEvent(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "An exception was thrown in the handler for the Reconnecting event.",
      exception,
      stackTrace,
    );
  }

  static void errorDuringReconnectedEvent(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "An exception was thrown in the handler for the Reconnected event.",
      exception,
      stackTrace,
    );
  }

  static void errorDuringNextRetryDelay(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "An exception was thrown from IRetryPolicy.NextRetryDelay().",
      exception,
      stackTrace,
    );
  }

  static void firstReconnectRetryDelayNull(Logger logger) {
    logger.log(
      Level.WARNING,
      "Connection not reconnecting because the IRetryPolicy returned null on the first reconnect attempt.",
    );
  }

  static void reconnectingStoppedDuringRetryDelay(Logger logger) {
    logger.log(
      Level.FINEST,
      "Connection stopped during reconnect delay. Done reconnecting.",
    );
  }

  static void reconnectingStoppedDuringReconnectAttempt(Logger logger) {
    logger.log(
      Level.FINEST,
      "Connection stopped during reconnect attempt. Done reconnecting.",
    );
  }

  static void attemptingStateTransition(
    Logger logger,
    HubConnectionState expectedState,
    HubConnectionState newState,
  ) {
    logger.log(
      Level.FINEST,
      "The HubConnection is attempting to transition from the $expectedState state to the $newState state.",
    );
  }

  static void errorInvalidHandshakeResponse(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINE,
      "Received an invalid handshake response.",
      exception,
      stackTrace,
    );
  }

  static void errorHandshakeTimedOut(
    Logger logger,
    Duration handshakeTimout,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "The handshake timed out after ${handshakeTimout.inSeconds} seconds.",
      exception,
      stackTrace,
    );
  }

  static void errorHandshakeCanceled(
    Logger logger,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "The handshake was canceled by the client.",
      exception,
      stackTrace,
    );
  }

  static void erroredStream(
    Logger logger,
    String streamId,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINEST,
      "Client threw an error for stream '$streamId'.",
      exception,
      stackTrace,
    );
  }

  static void missingResultHandler(
    Logger logger,
    String target,
  ) {
    logger.log(
      Level.WARNING,
      "Failed to find a value returning handler for '$target' method. Sending error to server.",
    );
  }

  static void resultNotExpected(
    Logger logger,
    String target,
  ) {
    logger.log(
      Level.WARNING,
      "Result given for '$target' method but server is not expecting a result.",
    );
  }

  static void completingStreamNotSent(
    Logger logger,
    String streamId,
  ) {
    logger.log(
      Level.FINEST,
      "Completion message for stream '$streamId}' was not sent because the connection is closed.",
    );
  }

  static void errorSendingInvocationResult(
    Logger logger,
    String invocationId,
    String target,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.WARNING,
      "Error returning result for invocation '$invocationId' for method '$target' because the underlying connection is closed.",
      exception,
      stackTrace,
    );
  }

  static void errorSendingStreamCompletion(
    Logger logger,
    String streamId,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.FINEST,
      "Error sending Completion message for stream '$streamId'.",
      exception,
      stackTrace,
    );
  }

  static void droppingMessage(
    Logger logger,
    String messageType,
    String? invocationId,
  ) {
    logger.log(
      Level.FINEST,
      "Dropping $messageType with ID '$invocationId'.",
    );
  }

  static void receivedAckMessage(
    Logger logger,
    int sequenceId,
  ) {
    logger.log(
      Level.FINEST,
      "Received AckMessage with Sequence ID '$sequenceId'.",
    );
  }

  static void receivedSequenceMessage(
    Logger logger,
    int sequenceId,
  ) {
    logger.log(
      Level.FINEST,
      "Received SequenceMessage with Sequence ID '$sequenceId'.",
    );
  }
}
