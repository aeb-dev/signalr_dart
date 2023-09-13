import "dart:async";

import "i_duplex_pipe.dart";

abstract interface class ConnectionContext {
  String? get connectionId;
  IDuplexPipe get transport;
  bool get hasInherentKeepAlive;
  bool get useStatefulReconnect;

  Future<void> dispose();
}
