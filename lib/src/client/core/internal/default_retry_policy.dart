import "../i_retry_policy.dart";
import "../retry_context.dart";

class DefaultRetryPolicy implements IRetryPolicy {
  static final List<Duration?> _defaultRetryDelaysInMiliseconds = <Duration?>[
    Duration.zero,
    const Duration(seconds: 2),
    const Duration(seconds: 10),
    const Duration(seconds: 30),
    null,
  ];

  late List<Duration?> _retryDelays;

  DefaultRetryPolicy([
    List<Duration>? retryDelays,
  ]) {
    if (retryDelays == null) {
      _retryDelays = _defaultRetryDelaysInMiliseconds;
    } else {
      _retryDelays =
          List<Duration?>.generate(retryDelays.length + 1, (int index) {
        if (index == retryDelays.length) {
          return null;
        }

        return retryDelays[index];
      });
    }
  }

  @override
  Duration? nextRetryDelay(RetryContext retryContext) =>
      _retryDelays[retryContext.previousRetryCount];
}
