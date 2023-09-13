// ignore_for_file: always_specify_types, strict_raw_type

part of "hub_connection.dart";

class Subscription {
  final InvocationHandler _handler;
  final InvocationHandlerList _handlerList;

  const Subscription(
    InvocationHandler handler,
    InvocationHandlerList handlerList,
  )   : _handler = handler,
        _handlerList = handlerList;

  void dispose() {
    _handlerList.remove(_handler);
  }
}
