import "dart:async";

import "hub_connection.dart";

extension HubConnectionOnResultExtensions on HubConnection {
  Subscription onResult0(
    String methodName,
    FutureOr<Object?> Function() handler,
  ) =>
      onResult(
        methodName,
        <Type>[],
        (List<Object?> args, Object? state) async {
          Object? result = await handler();
          return result;
        },
      );

  Subscription onResult1<T1>(
    String methodName,
    FutureOr<Object?> Function(
      T1 p1,
    ) handler, [
    T1 Function(dynamic)? creator1,
  ]) =>
      onResult(
        methodName,
        <Type>[T1],
        (List<Object?> args, Object? state) async {
          Object? result = await handler(
            args[0] as T1,
          );
          return result;
        },
        <Object? Function(dynamic)?>[
          creator1,
        ],
      );

  Subscription onResult2<T1, T2>(
    String methodName,
    FutureOr<Object?> Function(
      T1 p1,
      T2 p2,
    ) handler, [
    T1 Function(dynamic)? creator1,
    T2 Function(dynamic)? creator2,
  ]) =>
      onResult(
        methodName,
        <Type>[T1, T2],
        (List<Object?> args, Object? state) async {
          Object? result = await handler(
            args[0] as T1,
            args[1] as T2,
          );
          return result;
        },
        <Object? Function(dynamic)?>[
          creator1,
          creator2,
        ],
      );

  Subscription onResult3<T1, T2, T3>(
    String methodName,
    FutureOr<Object?> Function(
      T1 p1,
      T2 p2,
      T3 p3,
    ) handler, [
    T1 Function(dynamic)? creator1,
    T2 Function(dynamic)? creator2,
    T3 Function(dynamic)? creator3,
  ]) =>
      onResult(
        methodName,
        <Type>[T1, T2, T3],
        (List<Object?> args, Object? state) async {
          Object? result = await handler(
            args[0] as T1,
            args[1] as T2,
            args[2] as T3,
          );
          return result;
        },
        <Object? Function(dynamic)?>[
          creator1,
          creator2,
          creator3,
        ],
      );

  Subscription onResult4<T1, T2, T3, T4>(
    String methodName,
    FutureOr<Object?> Function(
      T1 p1,
      T2 p2,
      T3 p3,
      T4 p4,
    ) handler, [
    T1 Function(dynamic)? creator1,
    T2 Function(dynamic)? creator2,
    T3 Function(dynamic)? creator3,
    T4 Function(dynamic)? creator4,
  ]) =>
      onResult(
        methodName,
        <Type>[T1, T2, T3, T4],
        (List<Object?> args, Object? state) async {
          Object? result = await handler(
            args[0] as T1,
            args[1] as T2,
            args[2] as T3,
            args[3] as T4,
          );
          return result;
        },
        <Object? Function(dynamic)?>[
          creator1,
          creator2,
          creator3,
          creator4,
        ],
      );

  Subscription onResult5<T1, T2, T3, T4, T5>(
    String methodName,
    FutureOr<Object?> Function(
      T1 p1,
      T2 p2,
      T3 p3,
      T4 p4,
      T5 p5,
    ) handler, [
    T1 Function(dynamic)? creator1,
    T2 Function(dynamic)? creator2,
    T3 Function(dynamic)? creator3,
    T4 Function(dynamic)? creator4,
    T5 Function(dynamic)? creator5,
  ]) =>
      onResult(
        methodName,
        <Type>[T1, T2, T3, T4, T5],
        (List<Object?> args, Object? state) async {
          Object? result = await handler(
            args[0] as T1,
            args[1] as T2,
            args[2] as T3,
            args[3] as T4,
            args[4] as T5,
          );
          return result;
        },
        <Object? Function(dynamic)?>[
          creator1,
          creator2,
          creator3,
          creator4,
          creator5,
        ],
      );
}
