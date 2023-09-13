import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";

import "connection_context.dart";

abstract interface class IConnectionFactory {
  Future<ConnectionContext> connect(
    Uri endpoint, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]);
}
