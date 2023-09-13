import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";

import "../../../dotnet/i_duplex_pipe.dart";
import "../../../dotnet/transfer_format.dart";

abstract class ITransport extends IDuplexPipe {
  Future<void> start(
    Uri url,
    TransferFormat transferFormat, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]);
  Future<void> stop();
}
