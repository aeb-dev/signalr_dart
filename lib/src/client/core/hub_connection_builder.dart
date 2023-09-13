// ignore_for_file: use_setters_to_change_properties, avoid_returning_this

import "../../common/protocols/json/protocol/json_hub_protocol.dart";
import "../../common/protocols/message_pack/protocol/message_pack_hub_protocol.dart";
import "../../common/signalr/protocol/i_hub_protocol.dart";
import "../../dotnet/i_connection_factory.dart";
import "../../dotnet/invalid_operation_exception.dart";
import "../http_connections/http_connection_factory.dart";
import "../http_connections/http_connection_options.dart";
import "hub_connection.dart";
import "hub_connection_options.dart";
import "i_retry_policy.dart";
import "internal/default_retry_policy.dart";

class HubConnectionBuilder {
  bool _hubConnectionBuilt = false;

  IHubProtocol? _hubProtocol;
  IConnectionFactory? _connectionFactory;
  IRetryPolicy? _retryPolicy;

  final HubConnectionOptions _hubConnectionOptions = HubConnectionOptions();
  final HttpConnectionOptions _httpConnectionOptions = HttpConnectionOptions();

  HubConnectionBuilder.withUrl(
    Uri uri, [
    void Function(HttpConnectionOptions)? configureHttpConnection,
  ]) {
    _httpConnectionOptions.url = uri;
    configureHttpConnection?.call(_httpConnectionOptions);
  }

  HubConnectionBuilder withDelay(List<Duration> reconnectDelays) {
    _retryPolicy = DefaultRetryPolicy(reconnectDelays);
    return this;
  }

  HubConnectionBuilder withRetryPolicy(IRetryPolicy retryPolicy) {
    _retryPolicy = retryPolicy;
    return this;
  }

  HubConnectionBuilder withJson() {
    _hubProtocol = JsonHubProtocol();
    return this;
  }

  HubConnectionBuilder withMessagePack() {
    _hubProtocol = MessagePackHubProtocol();
    return this;
  }

  HubConnectionBuilder withConnectionFactory(
    IConnectionFactory connectionFactory,
  ) {
    _connectionFactory = connectionFactory;
    return this;
  }

  HubConnectionBuilder withServerTimeout(
    Duration timeout,
  ) {
    _hubConnectionOptions.serverTimeout = timeout;
    return this;
  }

  HubConnectionBuilder withKeepAliveInterval(
    Duration interval,
  ) {
    _hubConnectionOptions.keepAliveInterval = interval;
    return this;
  }

  HubConnectionBuilder withStatefulReconnect({int? bufferSize}) {
    _httpConnectionOptions.useStatefulReconnect = true;
    if (bufferSize != null) {
      _hubConnectionOptions.statefulReconnectBufferSize = bufferSize;
    }
    return this;
  }

  HubConnection build() {
    if (_hubConnectionBuilt) {
      throw InvalidOperationException(
        "HubConnectionBuilder allows creation only of a single instance of HubConnection.",
      );
    }

    _hubConnectionBuilt = true;

    _hubProtocol ??= JsonHubProtocol();

    _httpConnectionOptions.defaultTransferFormat = _hubProtocol!.transferFormat;

    _connectionFactory ??= HttpConnectionFactory(_httpConnectionOptions);

    return HubConnection(
      _connectionFactory!,
      _hubProtocol!,
      _httpConnectionOptions.url,
      _hubConnectionOptions,
      reconnectPolicy: _retryPolicy,
    );
  }
}
