import "dart:math" as math;

import "../../client/core/internal/serialized_hub_message.dart";
import "../signalr/protocol/i_hub_protocol.dart";

class LinkedBuffer {
  static const int _bufferLength = 10;

  int _currentIndex = -1;
  int _ackedIndex = -1;
  int _startingSequenceId = -9223372036854775808;
  LinkedBuffer? _next;

  final List<SerializedHubMessage?> _messages =
      List<SerializedHubMessage?>.filled(
    _bufferLength,
    null,
  );

  void addMessage(
    SerializedHubMessage hubMessage,
    int sequenceId,
  ) {
    if (_startingSequenceId < 0) {
      _startingSequenceId = sequenceId;
    }

    if (_currentIndex < _bufferLength - 1) {
      ++_currentIndex;
      _messages[_currentIndex] = hubMessage;
    } else if (_next == null) {
      _next = LinkedBuffer();
      _next!.addMessage(hubMessage, sequenceId);
    } else {
      // TODO: Should we avoid this path by keeping a tail pointer?
      // Debug.Assert(false);

      LinkedBuffer linkedBuffer = _next!;
      while (linkedBuffer._next != null) {
        linkedBuffer = linkedBuffer._next!;
      }

      // TODO: verify no stack overflow potential
      linkedBuffer.addMessage(hubMessage, sequenceId);
    }
  }

  (LinkedBuffer, int returnCredit) removeMessages(
    int sequenceId,
    IHubProtocol protocol,
  ) =>
      _removeMessagesCore(this, sequenceId, protocol);

  static (LinkedBuffer, int returnCredit) _removeMessagesCore(
    LinkedBuffer linkedBuffer,
    int sequenceId,
    IHubProtocol protocol,
  ) {
    int returnCredit = 0;
    while (linkedBuffer._startingSequenceId <= sequenceId) {
      int numElements = math.min(
        _bufferLength,
        math.max(1, sequenceId - (linkedBuffer._startingSequenceId - 1)),
      );

      for (int i = 0; i < numElements; i++) {
        returnCredit +=
            linkedBuffer._messages[i]?.getSerializedMessage(protocol).length ??
                0;
        linkedBuffer._messages[i] = null;
      }

      linkedBuffer._ackedIndex = numElements - 1;

      if (numElements == _bufferLength) {
        if (linkedBuffer._next == null) {
          linkedBuffer._reset(false);
          return (linkedBuffer, returnCredit);
        } else {
          LinkedBuffer tmp = linkedBuffer;
          // ignore: parameter_assignments
          linkedBuffer = linkedBuffer._next!;
          tmp._reset(true);
        }
      } else {
        return (linkedBuffer, returnCredit);
      }
    }

    return (linkedBuffer, returnCredit);
  }

  void _reset(bool shouldPool) {
    _startingSequenceId = -9223372036854775808;
    _currentIndex = -1;
    _ackedIndex = -1;
    _next = null;

    _messages.fillRange(0, _bufferLength, null);

    // TODO: Add back to pool
    if (shouldPool) {}
  }

  // ignore: use_to_and_as_if_applicable
  Iterable<(SerializedHubMessage?, int)> getMessages() =>
      _LinkedBufferIterable(this);
}

class _LinkedBufferIterable extends Iterable<(SerializedHubMessage?, int)> {
  final LinkedBuffer _linkedBuffer;

  _LinkedBufferIterable(this._linkedBuffer);

  @override
  Iterator<(SerializedHubMessage?, int)> get iterator =>
      _LinkedBufferIterator(_linkedBuffer);
}

class _LinkedBufferIterator implements Iterator<(SerializedHubMessage?, int)> {
  LinkedBuffer? _linkedBuffer;
  int _index = 0;

  _LinkedBufferIterator(this._linkedBuffer);

  @override
  (SerializedHubMessage?, int) get current {
    if (_linkedBuffer == null) {
      return (null, -9223372036854775808);
    }

    int index = _index - 1;
    int firstMessageIndex = _linkedBuffer!._ackedIndex + 1;
    if (firstMessageIndex + index < LinkedBuffer._bufferLength) {
      return (
        _linkedBuffer!._messages[firstMessageIndex + index],
        _linkedBuffer!._startingSequenceId + firstMessageIndex + index,
      );
    }

    return (null, -9223372036854775808);
  }

  @override
  bool moveNext() {
    if (_linkedBuffer == null) {
      return false;
    }

    int firstMessageIndex = _linkedBuffer!._ackedIndex + 1;
    if (firstMessageIndex + _index >= LinkedBuffer._bufferLength) {
      _linkedBuffer = _linkedBuffer!._next;
      _index = 1;
    } else {
      if (_linkedBuffer!._messages[firstMessageIndex + _index] == null) {
        _linkedBuffer = null;
      } else {
        _index++;
      }
    }

    return _linkedBuffer != null;
  }
}
