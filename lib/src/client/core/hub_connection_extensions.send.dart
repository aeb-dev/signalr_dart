import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";

import "hub_connection.dart";

extension HubConnectionSendExtensions on HubConnection {
  Future<void> send0(
    String methodName, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    await sendCore(
      methodName,
      <Object?>[],
      cancellationToken,
    );
  }

  Future<void> send1(
    String methodName,
    Object? p1, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    await sendCore(
      methodName,
      <Object?>[p1],
      cancellationToken,
    );
  }

  Future<void> send2(
    String methodName,
    Object? p1,
    Object? p2, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    await sendCore(
      methodName,
      <Object?>[p1, p2],
      cancellationToken,
    );
  }

  Future<void> send3(
    String methodName,
    Object? p1,
    Object? p2,
    Object? p3, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    await sendCore(
      methodName,
      <Object?>[p1, p2, p3],
      cancellationToken,
    );
  }

  Future<void> send4(
    String methodName,
    Object? p1,
    Object? p2,
    Object? p3,
    Object? p4, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    await sendCore(
      methodName,
      <Object?>[p1, p2, p3, p4],
      cancellationToken,
    );
  }

  Future<void> send5(
    String methodName,
    Object? p1,
    Object? p2,
    Object? p3,
    Object? p4,
    Object? p5, [
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async {
    await sendCore(
      methodName,
      <Object?>[p1, p2, p3, p4, p5],
      cancellationToken,
    );
  }
}
