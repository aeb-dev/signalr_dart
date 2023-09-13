import "package:msg_pck/msg_pck.dart";

import "message_pack_hub_protocol_worker.dart";

class DefaultMessagePackHubProtocolWorker extends MessagePackHubProtocolWorker {
  @override
  Object? deserializeObject(
    MessagePackReader reader,
    Type type,
    Object? Function(dynamic)? creator,
    String field,
  ) {
    try {
      Object? result = reader.read();
      if (result != null && creator != null) {
        result = creator(result);
      }

      return result;
    } on Exception catch (_) {
      throw FormatException(
        "Deserializing object of the `$type` type for '$field' failed.",
      );
    }
  }

  @override
  void serialize(MessagePackWriter writer, Type type, dynamic value) {
    writer.write(value);
  }
}
