enum HttpTransportType {
  none(0),
  webSockets(1),
  serverSentEvents(2),
  longPolling(4),
  all(7),
  ;

  final int value;

  const HttpTransportType(this.value);

  static HttpTransportType? tryParse(String value) {
    switch (value) {
      case "None":
        return HttpTransportType.none;
      case "WebSockets":
        return HttpTransportType.webSockets;
      case "ServerSentEvents":
        return HttpTransportType.serverSentEvents;
      case "LongPolling":
        return HttpTransportType.longPolling;
    }

    return null;
  }

  @override
  String toString() => switch (this) {
        HttpTransportType.none => "None",
        HttpTransportType.webSockets => "WebSockets",
        HttpTransportType.serverSentEvents => "ServerSentEvents",
        HttpTransportType.longPolling => "LongPolling",
        _ => throw Exception("Unreachable")
      };
}
