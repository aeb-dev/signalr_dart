import "package:cancellation_token_dotnet/cancellation_token_dotnet.dart";

import "hub_connection.dart";

extension HubConnectionStreamExtensions on HubConnection {
  Stream<T> stream0<T>(
    String methodName, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async* {
    yield* streamCore(
      methodName,
      T,
      <Object?>[],
      creator,
      cancellationToken,
    ).cast<T>();
  }

  Stream<T> stream1<T>(
    String methodName,
    Object? p1, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async* {
    yield* streamCore(
      methodName,
      T,
      <Object?>[p1],
      creator,
      cancellationToken,
    ).cast<T>();
  }

  Stream<T> stream2<T>(
    String methodName,
    Object? p1,
    Object? p2, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async* {
    yield* streamCore(
      methodName,
      T,
      <Object?>[p1, p2],
      creator,
      cancellationToken,
    ).cast<T>();
  }

  Stream<T> stream3<T>(
    String methodName,
    Object? p1,
    Object? p2,
    Object? p3, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async* {
    yield* streamCore(
      methodName,
      T,
      <Object?>[p1, p2, p3],
      creator,
      cancellationToken,
    ).cast<T>();
  }

  Stream<T> stream4<T>(
    String methodName,
    Object? p1,
    Object? p2,
    Object? p3,
    Object? p4, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async* {
    yield* streamCore(
      methodName,
      T,
      <Object?>[p1, p2, p3, p4],
      creator,
      cancellationToken,
    ).cast<T>();
  }

  Stream<T> stream5<T>(
    String methodName,
    Object? p1,
    Object? p2,
    Object? p3,
    Object? p4,
    Object? p5, [
    T Function(dynamic)? creator,
    CancellationToken cancellationToken = CancellationToken.none,
  ]) async* {
    yield* streamCore(
      methodName,
      T,
      <Object?>[p1, p2, p3, p4, p5],
      creator,
      cancellationToken,
    ).cast<T>();
  }
}
