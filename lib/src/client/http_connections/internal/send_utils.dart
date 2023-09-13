// ignore_for_file: avoid_classes_with_only_static_members

import "dart:async";
import "dart:typed_data";

import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:http/http.dart";
import "package:logging/logging.dart";

import "../../../dart_sse/sse_client.dart";
import "../../../dotnet/i_duplex_pipe.dart";

class SendUtils {
  static Future<void> sendMessages(
    Uri sendUrl,
    IDuplexPipe application,
    Client httpClient,
    Logger logger, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    _Log.sendStarted(logger);

    try {
      while (true) {
        ReadResult result = await application.input.read();
        Uint8List buffer = result.buffer.sublist(0);

        try {
          if (result.isCancelled) {
            _Log.sendCanceled(logger);
            break;
          }

          if (buffer.isNotEmpty) {
            // _Log.sendingMessages(logger, buffer.length, sendUrl);

            // Send them in a single post
            StreamedRequest request = StreamedRequest("POST", sendUrl);

            // ResponseHeadersRead instructs SendAsync to return once headers are read
            // rather than buffer the entire response. This gives a small perf boost.
            // Note that it is important to dispose of the response when doing this to
            // avoid leaving the connection open.

            Future<StreamedResponse> responseFuture = httpClient.send(request);

            request.sink.add(buffer);

            request.sink.close();

            await responseFuture;

            // _Log.sentSuccessfully(logger);
          } else if (result.isCompleted) {
            break;
          } else {
            _Log.noMessages(logger);
          }
        } finally {
          application.input.advanceTo(buffer.length);
        }
      }
    } on OperationCancelledException {
      _Log.sendCanceled(logger);
    } on Exception catch (ex, st) {
      _Log.errorSending(logger, sendUrl, ex, st);
      rethrow;
    } finally {
      application.input.complete();
    }

    _Log.sendStopped(logger);
  }

  static Future<void> sendSseMessages(
    Uri sendUrl,
    IDuplexPipe application,
    SseClient sseClient,
    Logger logger, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    _Log.sendStarted(logger);

    try {
      while (true) {
        ReadResult result = await application.input.read();
        Uint8List buffer = result.buffer.sublist(0);

        try {
          if (result.isCancelled) {
            _Log.sendCanceled(logger);
            break;
          }

          if (buffer.isNotEmpty) {
            // _Log.sendingMessages(logger, buffer.length, sendUrl);

            sseClient.sink.add(buffer);

            // _Log.sentSuccessfully(logger);
          } else if (result.isCompleted) {
            break;
          } else {
            _Log.noMessages(logger);
          }
        } finally {
          application.input.advanceTo(buffer.length);
        }
      }
    } on OperationCancelledException {
      _Log.sendCanceled(logger);
    } on Exception catch (ex, st) {
      _Log.errorSending(logger, sendUrl, ex, st);
      rethrow;
    } finally {
      application.input.complete();
    }

    _Log.sendStopped(logger);
  }
}

class _Log {
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

  // static void sendingMessages(Logger logger, int count, Uri url) {
  //   logger.log(
  //     Level.FINE,
  //     "Sending $count bytes to the server using url: $url.",
  //   );
  // }

  // static void sentSuccessfully(
  //   Logger logger,
  // ) {
  //   logger.log(Level.FINE, "Message(s) sent successfully.");
  // }

  static void noMessages(
    Logger logger,
  ) {
    logger.log(Level.FINE, "No messages in batch to send.");
  }

  static void errorSending(
    Logger logger,
    Uri url,
    Exception exception,
    StackTrace stackTrace,
  ) {
    logger.log(
      Level.SEVERE,
      "Error while sending to $url.",
      exception,
      stackTrace,
    );
  }
}
