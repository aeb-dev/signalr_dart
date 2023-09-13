class RetryContext {
  int previousRetryCount;
  Duration elapsedTime;
  Exception? retryReason;

  RetryContext(
    this.previousRetryCount,
    this.elapsedTime, [
    this.retryReason,
  ]);
}
