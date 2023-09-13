import "available_transport.dart";

class NegotiationResponse {
  String? url;
  String? accessToken;
  String? connectionId;
  String? connectionToken;
  late int version;
  List<AvailableTransport>? availableTransports;
  String? error;
  late bool useStatefulReconnect;
}
