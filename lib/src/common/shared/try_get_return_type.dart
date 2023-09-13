// ignore_for_file: avoid_classes_with_only_static_members

import "../signalr/i_invocation_binder.dart";

class ProtocolHelper {
  static Type? tryGetReturnType(IInvocationBinder binder, String invocationId) {
    try {
      return binder.getReturnType(invocationId);
    }
    // GetReturnType throws if invocationId not found, this can be caused by the server canceling a client-result but the client still sending a result
    // For now let's ignore the failure and skip parsing the result, server will log that the result wasn't expected anymore and ignore the message
    // In the future we may want a CompletionBindingFailureMessage that we can flow to the dispatcher for handling
    on Exception {
      return null;
    }
  }
}
