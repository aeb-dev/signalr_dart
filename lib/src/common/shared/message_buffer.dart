import "dart:async";
import "dart:typed_data";

import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";
import "package:meta/meta.dart";
import "package:pool/pool.dart";

import "../../../signalr_dart.dart";
import "../../client/core/internal/serialized_hub_message.dart";
import "../../dotnet/connection_context.dart";
import "../../dotnet/i_duplex_pipe.dart";
import "../signalr/protocol/ack_message.dart";
import "../signalr/protocol/hub_invocation_message.dart";
import "../signalr/protocol/hub_message.dart";
import "../signalr/protocol/i_hub_protocol.dart";
import "../signalr/protocol/sequence_message.dart";
import "linked_buffer.dart";

class MessageBuffer {
  static final Completer<void> _completedTCS = Completer<void>()..complete();

  final IHubProtocol _protocol;
  final int _bufferLimit;
  final AckMessage _ackMessage = AckMessage(0);
  final SequenceMessage _sequenceMessage = SequenceMessage(0);
  // ignore: close_sinks
  final StreamController<int> _waitForAck = StreamController<int>();
  late final BufferReader _ackBuffer;
  late final Timer _timer;
  final Pool _writeLock = Pool(1);

  BufferWriter _writer;

  int _totalMessageCount = 0;
  bool _waitForSequenceMessage = false;

  // Message IDs start at 1 and always increment by 1
  int _currentReceivingSequenceId = 1;
  int _latestReceivedSequenceId = -9223372036854775808;
  int _lastAckedId = -9223372036854775808;

  Completer<void> _resend = _completedTCS;

  Object get lock => _buffer;

  // TODO: pool
  LinkedBuffer _buffer = LinkedBuffer();
  int _bufferedByteCount = 0;

  MessageBuffer(
    ConnectionContext connection,
    IHubProtocol protocol,
    int bufferLimit,
  )   : _writer = connection.transport.output,
        _protocol = protocol,
        _bufferLimit = bufferLimit {
    _ackBuffer = BufferReader(_waitForAck.stream);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      _runTimer,
    );
  }

  Future<void> _runTimer(Timer timer) async {
    if (_lastAckedId < _latestReceivedSequenceId) {
      // TODO: consider a minimum time between sending these?

      int sequenceId = _latestReceivedSequenceId;

      _ackMessage.sequenceId = sequenceId;

      PoolResource pr = await _writeLock.request();
      try {
        _protocol.writeMessage(_ackMessage, _writer);
        _lastAckedId = sequenceId;
      } finally {
        pr.release();
      }
    }
  }

  Future<void> write(
    SerializedHubMessage hubMessage,
    CancellationToken cancellationToken,
  ) async {
    // TODO: Backpressure based on message count and total message size
    if (_bufferedByteCount > _bufferLimit) {
      // primitive backpressure if buffer is full
      while (true) {
        ReadResult result = await _ackBuffer.read(cancellationToken);
        if (result.isCompleted || result.isCancelled) {
          break;
        }

        Uint8List data = result.buffer.sublist(0);
        int count = data.last;
        if (count < _bufferLimit) {
          break;
        }

        _ackBuffer.advanceTo(data.length);
      }
    }

    // // Avoid condition where last Ack position is the position we're currently writing into the buffer
    // // If we wrote messages around the entire buffer before another Ack arrived we would end up reading the Ack position and writing over a buffered message
    // _waitForAck.stream.TryRead(out _);

    // TODO: We could consider buffering messages until they hit backpressure in the case when the connection is down
    await _resend.future;

    PoolResource pr = await _writeLock.request();
    try {
      if (hubMessage.message is HubInvocationMessage) {
        _totalMessageCount++;
      } else {
        // Non-ackable message, don't add to buffer
        _writer.add(hubMessage.getSerializedMessage(_protocol));
        return;
      }

      Uint8List messageBytes = hubMessage.getSerializedMessage(_protocol);
      _bufferedByteCount += messageBytes.length;
      _buffer.addMessage(hubMessage, _totalMessageCount);

      _writer.add(messageBytes);
      return;
    } finally {
      pr.release();
    }
  }

  void ack(AckMessage ackMessage) {
    // TODO: what if ackMessage.SequenceId is larger than last sent message?

    int newCount = -1;

    var (LinkedBuffer linkedBuffer, int returnCredit) =
        _buffer.removeMessages(ackMessage.sequenceId, _protocol);
    _buffer = linkedBuffer;
    _bufferedByteCount -= returnCredit;

    newCount = _bufferedByteCount;

    // Release potential backpressure
    if (newCount >= 0) {
      _waitForAck.sink.add(newCount);
    }
  }

  @internal
  bool shouldProcessMessage(HubMessage message) {
    // TODO: if we're expecting a sequence message but get here should we error or ignore or maybe even continue to process them?
    if (_waitForSequenceMessage) {
      if (message is SequenceMessage) {
        _waitForSequenceMessage = false;
        return true;
      } else {
        // ignore messages received while waiting for sequence message
        return false;
      }
    }

    // Only care about messages implementing HubInvocationMessage currently (e.g. ignore ping, close, ack, sequence)
    // Could expand in the future, but should probably rev the ack version if changes are made
    if (message is! HubInvocationMessage) {
      return true;
    }

    int currentId = _currentReceivingSequenceId;
    _currentReceivingSequenceId++;
    if (currentId <= _latestReceivedSequenceId) {
      // Ignore, this is a duplicate message
      return false;
    }
    _latestReceivedSequenceId = currentId;

    return true;
  }

  @internal
  void resetSequence(SequenceMessage sequenceMessage) {
    // TODO: is a sequence message expected right now?

    if (sequenceMessage.sequenceId > _currentReceivingSequenceId) {
      throw InvalidOperationException(
        "Sequence ID greater than amount of messages we've received.",
      );
    }
    _currentReceivingSequenceId = sequenceMessage.sequenceId;
  }

  @internal
  Future<void> resend(BufferWriter writer) async {
    _waitForSequenceMessage = true;

    Completer<void> tcs = Completer<void>();
    _resend = tcs;

    PoolResource pr = await _writeLock.request();
    try {
      // Complete previous pipe so transport reader can cleanup
      await _writer.complete();
      // Replace writer with new pipe that the transport will be reading from
      _writer = writer;

      _sequenceMessage.sequenceId = _totalMessageCount + 1;

      bool isFirst = true;
      for (var (SerializedHubMessage? hubMessage, int sequenceId)
          in _buffer.getMessages()) {
        if (sequenceId > 0) {
          if (isFirst) {
            _sequenceMessage.sequenceId = sequenceId;
            _protocol.writeMessage(_sequenceMessage, _writer);
            isFirst = false;
          }
          _writer.add(hubMessage!.getSerializedMessage(_protocol));
        }
      }

      if (isFirst) {
        _protocol.writeMessage(_sequenceMessage, _writer);
      }
    } on Exception catch (ex, st) {
      tcs.completeError(ex, st);
    } finally {
      pr.release();
      tcs.complete();
    }
  }

  void dispose() {
    _timer.cancel();
  }
}
