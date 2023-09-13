// ignore_for_file: avoid_classes_with_only_static_members

import "dart:typed_data";

import "package:jsontool/jsontool.dart";

import "../../dotnet/invalid_operation_exception.dart";
import "available_transport.dart";
import "negotiation_response.dart";

class NegotiateProtocol {
  static const String _connectionIdPropertyName = "connectionId";
  static const String _connectionTokenPropertyName = "connectionToken";
  static const String _urlPropertyName = "url";
  static const String _accessTokenPropertyName = "accessToken";
  static const String _availableTransportsPropertyName = "availableTransports";
  static const String _transportPropertyName = "transport";
  static const String _transferFormatsPropertyName = "transferFormats";
  static const String _errorPropertyName = "error";
  static const String _negotiateVersionPropertyName = "negotiateVersion";
  static const String _protocolVersionPropertyName = "ProtocolVersion";
  static const String _ackPropertyName = "useAck";

  NegotiateProtocol._();

  // static void writeResponse(
  //   NegotiationResponse response,
  //   Sink<List<int>> output,
  // ) {
  //   JsonWriter<List<int>> writer = jsonByteWriter(output, allowReuse: true)
  //     ..startObject();
  //   if (response.error != null) {
  //     writer
  //       ..addKey(_errorPropertyName)
  //       ..addString(response.error!)
  //       ..endObject();
  //     return;
  //   }

  //   if (response.useStatefulReconnect) {
  //     writer
  //       ..addKey(_ackPropertyName)
  //       ..addBool(true);
  //   }

  //   writer
  //     ..addKey(_negotiateVersionPropertyName)
  //     ..addNumber(response.version);

  //   if (response.url != null) {
  //     writer
  //       ..addKey(_urlPropertyName)
  //       ..addString(response.url!);
  //   }

  //   if (response.accessToken != null) {
  //     writer
  //       ..addKey(_accessTokenPropertyName)
  //       ..addString(response.accessToken!);
  //   }

  //   if (response.connectionId != null) {
  //     writer
  //       ..addKey(_connectionIdPropertyName)
  //       ..addString(response.connectionId!);
  //   }

  //   if (response.version > 0 && response.connectionId != null) {
  //     writer
  //       ..addKey(_connectionTokenPropertyName)
  //       ..addString(response.connectionToken!);
  //   }

  //   writer
  //     ..addKey(_availableTransportsPropertyName)
  //     ..startArray();

  //   if (response.availableTransports != null) {
  //     for (AvailableTransport availableTransport
  //         in response.availableTransports!) {
  //       writer.startObject();

  //       if (availableTransport.transport != null) {
  //         writer
  //           ..addKey(_transportPropertyName)
  //           ..addString(availableTransport.transport!);
  //       }

  //       writer
  //         ..addKey(_transferFormatsPropertyName)
  //         ..startArray();

  //       if (availableTransport.transferFormats != null) {
  //         for (String transferFormat in availableTransport.transferFormats!) {
  //           writer.addString(transferFormat);
  //         }
  //       }

  //       writer
  //         ..endArray()
  //         ..endObject();
  //     }
  //   }

  //   writer
  //     ..endArray()
  //     ..endObject();
  // }

  static NegotiationResponse parseResponse(Uint8List content) {
    try {
      JsonReader<Uint8List> reader = JsonReader.fromUtf8(content)
        ..expectObject();
      String? connectionId;
      String? connectionToken;
      String? url;
      String? accessToken;
      List<AvailableTransport>? availableTransports;
      String? error;
      int version = 0;
      bool useStatefulReconnect = false;

      while (true) {
        String? key = reader.nextKey();
        if (key == null) {
          break;
        }

        switch (key) {
          case _urlPropertyName:
            url = reader.expectString();
          case _accessTokenPropertyName:
            accessToken = reader.expectString();
          case _connectionIdPropertyName:
            connectionId = reader.expectString();
          case _connectionTokenPropertyName:
            connectionToken = reader.expectString();
          case _negotiateVersionPropertyName:
            version = reader.expectInt();
          case _availableTransportsPropertyName:
            reader.expectArray();

            availableTransports =
                List<AvailableTransport>.empty(growable: true);
            while (reader.hasNext()) {
              bool isObject = reader.tryObject();
              if (isObject) {
                AvailableTransport availableTransport =
                    _parseAvailableTransport(reader);
                availableTransports.add(availableTransport);
              }
            }
          case _errorPropertyName:
            error = reader.expectString();
          case _protocolVersionPropertyName:
            throw InvalidOperationException(
              "Detected a connection attempt to an ASP.NET SignalR Server. This client only supports connecting to an ASP.NET Core SignalR Server. See https://aka.ms/signalr-core-differences for details.",
            );
          case _ackPropertyName:
            useStatefulReconnect = reader.expectBool();
          default:
            reader.skipAnyValue();
        }
      }

      if (url == null && error == null) {
        // if url isn't specified or there isn't an error, connectionId and available transports are required
        if (connectionId == null) {
          throw const FormatException(
            "Missing required property $_connectionIdPropertyName'.",
          );
        }

        if (version > 0) {
          if (connectionToken == null) {
            throw const FormatException(
              "Missing required property $_connectionTokenPropertyName'.",
            );
          }
        }

        if (availableTransports == null) {
          throw const FormatException(
            "Missing required property $_availableTransportsPropertyName'.",
          );
        }
      }

      return NegotiationResponse()
        ..connectionId = connectionId
        ..connectionToken = connectionToken
        ..url = url
        ..accessToken = accessToken
        ..availableTransports = availableTransports
        ..error = error
        ..version = version
        ..useStatefulReconnect = useStatefulReconnect;
    } on Exception catch (ex) {
      throw FormatException("Invalid negotiation response received. $ex");
    }
  }

  static AvailableTransport _parseAvailableTransport(
    JsonReader<List<int>> reader,
  ) {
    AvailableTransport availableTransport = AvailableTransport();

    while (true) {
      String? key = reader.nextKey();
      if (key == null) {
        break;
      }

      switch (key) {
        case _transportPropertyName:
          availableTransport.transport = reader.expectString();
        case _transferFormatsPropertyName:
          reader.expectArray();

          availableTransport.transferFormats =
              List<String>.empty(growable: true);
          while (reader.hasNext()) {
            String transferFormat = reader.expectString();
            availableTransport.transferFormats!.add(transferFormat);
          }
        default:
          reader.skipAnyValue();
      }
    }

    if (availableTransport.transport == null) {
      throw const FormatException(
        "Missing required property $_transportPropertyName.",
      );
    }

    if (availableTransport.transferFormats == null) {
      throw const FormatException(
        "Missing required property $_transferFormatsPropertyName.",
      );
    }

    return availableTransport;
  }
}
