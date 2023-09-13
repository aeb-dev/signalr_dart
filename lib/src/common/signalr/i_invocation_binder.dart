import "dart:typed_data";

abstract interface class IInvocationBinder {
  Object? Function(dynamic)? getReturnTypeCreator(String invocationId);
  Type getReturnType(String invocationId);
  List<Object? Function(dynamic)?> getParameterTypesCreator(String methodName);
  List<Type> getParameterTypes(String methodName);
  Type getStreamItemType(String streamId);
  String? getTarget(Uint8List utf8Bytes) => null;
}
