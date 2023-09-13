import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";

import "hub_connection.dart";

extension HubConnectionInvokeExtensions on HubConnection {
  Future<T> invoke0<T>(
    String methodName, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async =>
      await invokeCore(
        methodName,
        T,
        <Object?>[],
        creator,
        cancellationToken,
      ) as T;

  Future<T> invoke1<T>(
    String methodName,
    Object? p1, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async =>
      await invokeCore(
        methodName,
        T,
        <Object?>[p1],
        creator,
        cancellationToken,
      ) as T;

  Future<T> invoke2<T>(
    String methodName,
    Object? p1,
    Object? p2, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async =>
      await invokeCore(
        methodName,
        T,
        <Object?>[p1, p2],
        creator,
        cancellationToken,
      ) as T;

  Future<T> invoke3<T>(
    String methodName,
    Object? p1,
    Object? p2,
    Object? p3, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async =>
      await invokeCore(
        methodName,
        T,
        <Object?>[p1, p2, p3],
        creator,
        cancellationToken,
      ) as T;

  Future<T> invoke4<T>(
    String methodName,
    Object? p1,
    Object? p2,
    Object? p3,
    Object? p4, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async =>
      await invokeCore(
        methodName,
        T,
        <Object?>[p1, p2, p3, p4],
        creator,
        cancellationToken,
      ) as T;

  Future<T> invoke5<T>(
    String methodName,
    Object? p1,
    Object? p2,
    Object? p3,
    Object? p4,
    Object? p5, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async =>
      await invokeCore(
        methodName,
        T,
        <Object?>[p1, p2, p3, p4, p5],
        creator,
        cancellationToken,
      ) as T;
}
