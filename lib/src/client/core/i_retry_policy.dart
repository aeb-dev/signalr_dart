import "retry_context.dart";

abstract interface class IRetryPolicy {
  Duration? nextRetryDelay(RetryContext retryContext);
}
