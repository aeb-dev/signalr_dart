<p>
  <a title="Pub" href="https://pub.dev/packages/signalr_dart" ><img src="https://img.shields.io/pub/v/signalr_dart.svg?style=popout" /></a>
</p>

A complete SignalR Client including stateful reconnect in dart. You will feel right at home while using this library because APIs are kept as similar as possible.

I know that there are a lot of other SignalR clients in dart but either they have problems because they don't follow SignalR client code flow in the first place or they have been discontinued or not been maintained. You can verify by comparing repositories against [SignalR C# client](https://github.com/dotnet/aspnetcore/tree/v7.0.5/src/SignalR/clients/csharp) repository.

All platforms are supported. Tested on windows and browsers

Supported transports:
- WebSocket
- ServerSentEvents (SSE)
- Long Polling

Supported hub protocols:
- Json
- Message Pack (SSE does not support) (Use [this package](https://github.com/aeb-dev/message_pack_dart) to be able work with Message Pack)

You can find full examples [here](https://github.com/aeb-dev/signalr_dart/tree/main/example) folder. There is also a test server provided [here](https://github.com/aeb-dev/signalr_dart_test_server)

TODOs:
- Http2
- Proxy
- Implementing server side (not anytime soon)
