class TransportFailedException implements Exception {
  final String transportType;
  final String message;

  TransportFailedException(
    this.transportType,
    this.message,
  );
}
