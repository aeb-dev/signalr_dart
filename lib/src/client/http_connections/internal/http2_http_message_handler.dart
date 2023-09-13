// import "dart:io";

// import "package:http/http.dart";
// import "package:http2/http2.dart";
// import "package:logging/logging.dart";
// import "package:stream_channel/stream_channel.dart";

// import "../../../extensions/base_response.dart";
// import "http_message_handler.dart";

// class Http2HttpMessageHandler extends HttpMessageHandler {
//   ClientTransportConnection? _transport;
//   final StreamChannelController<List<int>> _channel = StreamChannelController<List<int>>();
//   // final Pipe pipe = Pipe.createSync();

//   Http2HttpMessageHandler(super.innerClient, super.httpConnectionOptions);

//   @override
//   Future<StreamedResponse> send(BaseRequest request) async {
//     ByteStream content = request.finalize();
//     _transport ??= ClientTransportConnection.viaSocket(await SecureSocket.connect(
//       httpConnectionOptions.url!.host,
//       httpConnectionOptions.url!.port,
//       supportedProtocols: <String>["http/1.1","h2"],
//     ),);

//     ClientTransportStream clientTransportStream = _transport!.makeRequest([])

//     ..sendData(content.toBytes() as List<int>);

//     StreamedResponse streamedResponse = StreamedResponse(stream, statusCode);
//     await for (StreamMessage streamMessage in clientTransportStream.incomingMessages) {
//       switch (streamMessage)
//         {
//           case HeadersStreamMessage headersStreamMessage:
//           case DataStreamMessage dataStreamMessage:

//         }
//     }

//     return streamedResponse;
//   }

//   @override
//   Future<void> close() async {
//     await _transport?.finish();
//   }
// }
