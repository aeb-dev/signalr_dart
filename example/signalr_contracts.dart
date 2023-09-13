// ignore_for_file: avoid_dynamic_calls

import "package:msg_pck/msg_pck.dart";

class ClientRequest with MessagePackObject {
  final int messageId;
  final String message;
  final DateTime dateTime;

  ClientRequest(
    this.messageId,
    this.message,
    this.dateTime,
  );

  @override
  List<dynamic> get messagePackFields =>
      <dynamic>[messageId, message, dateTime];

  Map<String, dynamic> toJson() => <String, dynamic>{
        "messageId": messageId,
        "message": message,
        "dateTime": dateTime.toIso8601String(),
      };

  ClientRequest.fromJson(Map<String, dynamic> json)
      : messageId = json["messageId"] as int,
        message = json["message"] as String,
        dateTime = DateTime.parse(json["dateTime"] as String);

  ClientRequest.fromMessagePack(List<dynamic> items)
      : messageId = items[0] as int,
        message = items[1] as String,
        dateTime = items[2] as DateTime;

  @override
  String toString() => """
    messageId: $messageId,
    message: $message,
    dateTime: $dateTime""";
}

class ServerResponse with MessagePackObject {
  final int messageId;
  final int messageIdOfRequest;
  final String message;
  final DateTime dateTime;
  final ClientRequest request;
  final String? traceId;

  ServerResponse(
    this.messageId,
    this.messageIdOfRequest,
    this.message,
    this.dateTime,
    this.request, [
    this.traceId,
  ]);

  @override
  List<dynamic> get messagePackFields => <dynamic>[
        messageId,
        messageIdOfRequest,
        message,
        dateTime,
        request,
        traceId,
      ];

  ServerResponse.fromJson(dynamic json)
      : assert(json is Map<String, dynamic>, ""),
        messageId = json["messageId"] as int,
        messageIdOfRequest = json["messageIdOfRequest"] as int,
        message = json["message"] as String,
        dateTime = DateTime.parse(json["dateTime"] as String),
        request = ClientRequest.fromJson(
          json["request"] as Map<String, dynamic>,
        ),
        traceId = json["traceId"] as String?;

  ServerResponse.fromMessagePack(dynamic items)
      : assert(items is List<dynamic>, ""),
        messageId = items[0] as int,
        messageIdOfRequest = items[1] as int,
        message = items[2] as String,
        dateTime = items[3] as DateTime,
        request = ClientRequest.fromMessagePack(items[4] as List<dynamic>),
        traceId = items[5] as String?;

  @override
  String toString() => """
    messageId: $messageId,
    messageIdOfRequest: $messageIdOfRequest,
    message: $message,
    dateTime: $dateTime,
    request: $request,
    traceId: $traceId""";
}

class ServerRequest with MessagePackObject {
  final int messageId;
  final String message;
  final DateTime dateTime;
  final String? helperText;
  final List<dynamic>? possibleAnswers;

  ServerRequest(
    this.messageId,
    this.message,
    this.dateTime,
    this.helperText,
    this.possibleAnswers,
  );

  @override
  List<dynamic> get messagePackFields => <dynamic>[
        messageId,
        message,
        dateTime,
        helperText,
        possibleAnswers,
      ];

  Map<String, dynamic> toJson() => <String, dynamic>{
        "messageId": messageId,
        "message": message,
        "dateTime": dateTime.toIso8601String(),
        "helperText": helperText,
        "possibleAnswers": possibleAnswers,
      };

  ServerRequest.fromJson(dynamic json)
      : assert(json is Map<String, dynamic>, ""),
        messageId = json["messageId"] as int,
        message = json["message"] as String,
        dateTime = DateTime.parse(json["dateTime"] as String),
        helperText = json["helperText"] as String,
        possibleAnswers = json["possibleAnswers"] as List<dynamic>?;

  ServerRequest.fromMessagePack(dynamic items)
      : assert(items is List<dynamic>, ""),
        messageId = items[0] as int,
        message = items[1] as String,
        dateTime = items[2] as DateTime,
        helperText = items[3] as String,
        possibleAnswers = items[4] as List<dynamic>?;

  @override
  String toString() => """
    messageId: $messageId,
    message: $message,
    dateTime: $dateTime,
    helperText: $helperText,
    possibleAnswers: $possibleAnswers""";
}

class ClientResponse with MessagePackObject {
  final int messageId;
  final int messageIdOfRequest;
  final String message;
  final DateTime dateTime;
  final double responseConfidence;
  final Map<String, dynamic>? bagOfData;
  final ServerRequest request;
  final String? traceId;

  ClientResponse(
    this.messageId,
    this.messageIdOfRequest,
    this.message,
    this.dateTime,
    this.responseConfidence,
    this.bagOfData,
    this.request, [
    this.traceId,
  ]);

  @override
  List<dynamic> get messagePackFields => <dynamic>[
        messageId,
        messageIdOfRequest,
        message,
        dateTime,
        responseConfidence,
        bagOfData,
        request,
        traceId,
      ];

  Map<String, dynamic> toJson() => <String, dynamic>{
        "messageId": messageId,
        "messageIdOfRequest": messageIdOfRequest,
        "message": message,
        "dateTime": dateTime.toIso8601String(),
        "responseConfidence": responseConfidence,
        "bagOfData": bagOfData,
        "request": request,
        "traceId": traceId,
      };

  @override
  String toString() => """
    messageId: $messageId,
    messageIdOfRequest: $messageIdOfRequest,
    message: $message,
    dateTime: $dateTime,
    responseConfidence: $responseConfidence,
    bagOfData: $bagOfData,
    request: $request,
    traceId: $traceId""";
}
