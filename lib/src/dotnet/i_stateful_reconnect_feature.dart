import "i_duplex_pipe.dart";

abstract interface class IStatefulReconnectFeature {
  void onReconnected(
    Future<void> Function(BufferWriter writer) notifyOnReconnect,
  );
  void disableReconnect();
}
