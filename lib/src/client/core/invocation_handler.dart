part of "hub_connection.dart";

class InvocationHandler {
  final List<Type> parameterTypes;
  bool hasResult;
  final FutureOr<Object?> Function(List<Object?>, Object?) _callback;
  final List<Object? Function(dynamic)?> creators;
  final Object? _state;

  InvocationHandler(
    this.parameterTypes,
    this._callback,
    this.creators,
    Object? state, {
    // ignore: always_put_required_named_parameters_first
    required this.hasResult,
  }) : _state = state;

  FutureOr<dynamic> invoke(List<Object?> parameters) =>
      _callback.call(parameters, _state);
}
