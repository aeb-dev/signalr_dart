class HubConnectionOptions {
  static const Duration defaultServerTimout = Duration(seconds: 30);
  static const Duration defaultKeepAliveInterval = Duration(seconds: 15);
  static const Duration defaultHandshakeTimeout = Duration(seconds: 15);
  static const int defaultStatefulReconnectBufferSize = 100000;

  Duration serverTimeout = defaultServerTimout;
  Duration keepAliveInterval = defaultKeepAliveInterval;
  Duration handshakeTimeout = defaultHandshakeTimeout;
  int statefulReconnectBufferSize = defaultStatefulReconnectBufferSize;
}
