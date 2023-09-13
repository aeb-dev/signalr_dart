import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:meta/meta.dart";
import "package:typed_data/typed_buffers.dart";

import "invalid_operation_exception.dart";

abstract class IDuplexPipe {
  BufferReader get input;
  BufferWriter get output;
}

class BufferReader {
  final Stream<dynamic> stream;
  late final StreamSubscription<dynamic> _subscription;

  bool _isStreamDone = false;

  // these are for read result
  bool _isCompleted = false;
  bool _isCancelled = false;

  final Uint8Buffer _buffer = Uint8Buffer();
  Completer<void> _completer = Completer<void>();

  BufferReader(this.stream) {
    _subscription = stream.listen(
      (dynamic data) {
        if (data is String) {
          addString(data);
        } else if (data is List<int>) {
          add(data);
        }
      },
      onDone: complete,
    );
  }

  Future<ReadResult> read([
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    if (_isStreamDone) {
      throw InvalidOperationException("Can not read from finished buffer");
    }

    CancellationTokenRegistration? cancellationTokenRegistration;
    cancellationTokenRegistration = cancellationToken.register<void>(
      callback: (_, __) async {
        _isCompleted = false;
        _isCancelled = true;

        if (!_completer.isCompleted) {
          _completer.complete();
        }
        cancellationTokenRegistration?.dispose();
      },
    );

    await _completer.future;

    cancellationToken.throwIfCancellationRequested();

    if (!_isStreamDone) {
      _completer = Completer<void>();
    }

    return ReadResult._(
      _isCompleted,
      _isCancelled,
      _buffer.buffer.asUint8List(_buffer.offsetInBytes, _buffer.lengthInBytes),
    );
  }

  @internal
  void complete() {
    if (_isStreamDone) {
      return;
    }

    _isStreamDone = true;

    _isCompleted = true;
    _isCancelled = false;

    if (!_completer.isCompleted) {
      _completer.complete();
    } else {
      _completer = Completer<void>()..complete();
    }
  }

  @internal
  void add(List<int> data) {
    if (_isStreamDone) {
      return;
    }

    _buffer.addAll(data);

    _isCompleted = false;
    _isCancelled = false;

    if (!_completer.isCompleted) {
      _completer.complete();
    } else {
      _completer = Completer<void>()..complete();
    }
  }

  @internal
  void addByte(int data) {
    if (_isStreamDone) {
      return;
    }

    _buffer.add(data);

    _isCompleted = false;
    _isCancelled = false;

    if (!_completer.isCompleted) {
      _completer.complete();
    } else {
      _completer = Completer<void>()..complete();
    }
  }

  @internal
  void addString(String value) {
    if (_isStreamDone) {
      return;
    }

    List<int> data = utf8.encode(value);

    _buffer.addAll(data);

    _isCompleted = false;
    _isCancelled = false;

    if (!_completer.isCompleted) {
      _completer.complete();
    } else {
      _completer = Completer<void>()..complete();
    }
  }

  void cancelPendingRead() {
    if (_isStreamDone) {
      return;
    }

    _isCompleted = false;
    _isCancelled = true;

    if (!_completer.isCompleted) {
      _completer.complete();
    } else {
      _completer = Completer<void>()..complete();
    }
  }

  void advanceTo(int position) {
    _buffer.removeRange(0, position);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    complete();
    _buffer.clear();
  }
}

class ReadResult {
  final bool isCompleted;
  final bool isCancelled;
  final Uint8List buffer;

  const ReadResult._(
    this.isCompleted,
    this.isCancelled,
    this.buffer,
  );
}

class BufferWriter {
  final _NonClosingSink _sink;

  final Completer<void> _completer = Completer<void>();

  Sink<List<int>> get sink => _sink;

  bool get isCompleted => _completer.isCompleted;

  BufferWriter(Sink<List<int>> sink) : _sink = _NonClosingSink(sink);

  void add(List<int> data) {
    sink.add(data);
  }

  // Future<void> addStream(Stream<List<int>> stream) async {

  //   await sink.addStream(stream);

  //   // FlushResult flushResult = await flush();
  //   // return flushResult;
  // }

  Future<void> complete([
    Exception? error,
    StackTrace? stackTrace,
  ]) async {
    if (isCompleted) {
      return;
    }

    await _sink._close();

    _completer.complete();
  }

  Future<void> dispose() async {
    await complete();
  }
}

class _NonClosingSink extends ByteConversionSink {
  final Sink<List<int>> _sink;

  _NonClosingSink(this._sink);

  @override
  void add(List<int> data) => _sink.add(data);

  @override
  void close() {
    // do nothing
  }

  // Actually close.
  Future<void> _close([
    Exception? error,
    StackTrace? stackTrace,
  ]) async {
    if (_sink is StreamSink<List<int>>) {
      StreamSink<List<int>> sink_ = _sink as StreamSink<List<int>>;
      if (error != null) {
        sink_.addError(error, stackTrace);
      }
      await sink_.close();
    } else {
      _sink.close();
    }
  }
}
