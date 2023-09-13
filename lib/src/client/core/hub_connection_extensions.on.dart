import "dart:async";

import "hub_connection.dart";

extension HubConnectionOnExtensions on HubConnection {
  Subscription on0(
    String methodName,
    FutureOr<void> Function() handler,
  ) =>
      on(
        methodName,
        <Type>[],
        (List<Object?> args, Object? state) async {
          await handler();
        },
      );

  Subscription on1<T1>(
    String methodName,
    FutureOr<void> Function(
      T1 p1,
    ) handler, [
    T1 Function(dynamic)? creator1,
  ]) =>
      on(
        methodName,
        <Type>[T1],
        (List<Object?> args, Object? state) async {
          await handler(
            args[0] as T1,
          );
        },
        <Object? Function(dynamic)?>[
          creator1,
        ],
      );

  Subscription on2<T1, T2>(
    String methodName,
    FutureOr<void> Function(
      T1 p1,
      T2 p2,
    ) handler, [
    T1 Function(dynamic)? creator1,
    T2 Function(dynamic)? creator2,
  ]) =>
      on(
        methodName,
        <Type>[T1, T2],
        (List<Object?> args, Object? state) async {
          await handler(
            args[0] as T1,
            args[1] as T2,
          );
        },
        <Object? Function(dynamic)?>[
          creator1,
          creator2,
        ],
      );

  Subscription on3<T1, T2, T3>(
    String methodName,
    FutureOr<void> Function(
      T1 p1,
      T2 p2,
      T3 p3,
    ) handler, [
    T1 Function(dynamic)? creator1,
    T2 Function(dynamic)? creator2,
    T3 Function(dynamic)? creator3,
  ]) =>
      on(
        methodName,
        <Type>[T1, T2, T3],
        (List<Object?> args, Object? state) async {
          await handler(
            args[0] as T1,
            args[1] as T2,
            args[2] as T3,
          );
        },
        <Object? Function(dynamic)?>[
          creator1,
          creator2,
          creator3,
        ],
      );

  Subscription on4<T1, T2, T3, T4>(
    String methodName,
    FutureOr<void> Function(
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
      on(
        methodName,
        <Type>[T1, T2, T3, T4],
        (List<Object?> args, Object? state) async {
          await handler(
            args[0] as T1,
            args[1] as T2,
            args[2] as T3,
            args[3] as T4,
          );
        },
        <Object? Function(dynamic)?>[
          creator1,
          creator2,
          creator3,
          creator4,
        ],
      );

  Subscription on5<T1, T2, T3, T4, T5>(
    String methodName,
    FutureOr<void> Function(
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
      on(
        methodName,
        <Type>[T1, T2, T3, T4, T5],
        (List<Object?> args, Object? state) async {
          await handler(
            args[0] as T1,
            args[1] as T2,
            args[2] as T3,
            args[3] as T4,
            args[4] as T5,
          );
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
