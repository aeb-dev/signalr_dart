import "dart:typed_data";

import "package:meta/meta.dart";

import "../../../../signalr_dart.dart";
import "../../../common/signalr/protocol/hub_message.dart";
import "../../../common/signalr/protocol/i_hub_protocol.dart";

typedef SerializedMessage = (String protocolName, Uint8List serialized);

class SerializedHubMessage {
  SerializedMessage? _cachedItem1;
  SerializedMessage? _cachedItem2;
  final List<SerializedMessage> _cachedItems = <SerializedMessage>[];
  // final Pool _pool = Pool(1);

  HubMessage? message;

  SerializedHubMessage(List<SerializedMessage> messages) {
    for (var (String protocolName, Uint8List serialized) in messages) {
      _setCacheUnsynchronized(protocolName, serialized);
    }
  }

  SerializedHubMessage.fromMessage(this.message);

  Uint8List getSerializedMessage(IHubProtocol protocol) {
    Uint8List? serialized = _tryGetCachedUnsynchronized(protocol.name);
    if (serialized == null) {
      if (message == null) {
        throw InvalidOperationException(
          "This message was received from another server that did not have the requested protocol available.",
        );
      }

      serialized = protocol.getMessageBytes(message!);
      _setCacheUnsynchronized(protocol.name, serialized);
    }

    return serialized;
  }

  @visibleForTesting
  List<SerializedMessage> getAllSerializations() {
    if (_cachedItem1 == null) {
      return List<SerializedMessage>.empty();
    }

    List<SerializedMessage> list = List<SerializedMessage>.empty(growable: true)
      ..add(_cachedItem1!);

    if (_cachedItem2 != null) {
      list.add(_cachedItem2!);

      if (_cachedItems.isNotEmpty) {
        list.addAll(_cachedItems);
      }
    }

    return list;
  }

  void _setCacheUnsynchronized(String protocolName, Uint8List serialized) {
    if (_cachedItem1 == null) {
      _cachedItem1 = (protocolName, serialized);
    } else if (_cachedItem2 == null) {
      _cachedItem2 = (protocolName, serialized);
    } else {
      for (var (String cachedProtocolName, _) in _cachedItems) {
        if (cachedProtocolName == protocolName) {
          // No need to add
          return;
        }
      }

      _cachedItems.add((protocolName, serialized));
    }
  }

  Uint8List? _tryGetCachedUnsynchronized(String protocolName) {
    if (_cachedItem1 != null) {
      var (String cacheProtocolName, Uint8List cacheSerialized) = _cachedItem1!;
      if (cacheProtocolName == protocolName) {
        return cacheSerialized;
      }
    }

    if (_cachedItem2 != null) {
      var (String cacheProtocolName, Uint8List cacheSerialized) = _cachedItem2!;
      if (cacheProtocolName == protocolName) {
        return cacheSerialized;
      }
    }

    for (var (
          String cacheProtocolName,
          Uint8List cacheSerialized,
        ) in _cachedItems) {
      if (cacheProtocolName == protocolName) {
        return cacheSerialized;
      }
    }

    return null;
  }
}
