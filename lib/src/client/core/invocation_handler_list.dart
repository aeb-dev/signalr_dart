part of "hub_connection.dart";

class InvocationHandlerList {
  final List<InvocationHandler> _handlers = <InvocationHandler>[];
  bool _hasHandlerWithResult = false;

  InvocationHandlerList(InvocationHandler handler) {
    _handlers.add(handler);
  }

  List<InvocationHandler> get handlers => _handlers;

  void add(
    String methodName,
    InvocationHandler handler,
  ) {
    if (handler.hasResult) {
      if (_hasHandlerWithResult) {
        throw Exception(
          "'$methodName' already has a value returning handler. Multiple return values are not supported.",
        );
      }

      _hasHandlerWithResult = true;
    }

    handlers.add(handler);
  }

  void remove(
    InvocationHandler handler,
  ) {
    if (handler.hasResult) {
      _hasHandlerWithResult = false;
    }

    handlers.remove(handler);
  }
}
