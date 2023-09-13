import "../../../common/http_connections/http_transport_type.dart";
import "i_transport.dart";

abstract interface class ITransportFactory {
  ITransport createTransport(
    HttpTransportType availableServerTransports, {
    bool useStatefulReconnect = false,
  });
}
