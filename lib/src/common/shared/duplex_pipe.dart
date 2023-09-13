import "dart:async";

import "../../dotnet/i_duplex_pipe.dart";

class DuplexPipe extends IDuplexPipe {
  final BufferReader _input;
  final BufferWriter _output;

  @override
  BufferReader get input => _input;

  @override
  BufferWriter get output => _output;

  DuplexPipe(
    Stream<dynamic> input,
    StreamSink<List<int>> output,
  )   : _input = BufferReader(input),
        _output = BufferWriter(output);

  static (
    IDuplexPipe transport,
    IDuplexPipe application,
  ) createConnectionPair() {
    // ignore: close_sinks
    StreamController<List<int>> input = StreamController<List<int>>();
    // ignore: close_sinks
    StreamController<List<int>> output = StreamController<List<int>>();

    DuplexPipe transportToApplication = DuplexPipe(
      output.stream,
      input.sink,
    );
    DuplexPipe applicationToTransport = DuplexPipe(
      input.stream,
      output.sink,
    );

    return (
      applicationToTransport,
      transportToApplication,
    );
  }

  Future<void> dispose() async {
    await _input.dispose();
    await _output.complete();
  }
}
