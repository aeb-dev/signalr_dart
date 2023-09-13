// ignore_for_file: library_prefixes, avoid_classes_with_only_static_members

import "package:os_detect/os_detect.dart" as Platform;

class Constants {
  Constants._();

  static const String userAgent = "X-SignalR-User-Agent";
  static final String userAgentHeader =
      "Microsoft SignalR/1.0 (Unknown Version; ${Platform.operatingSystem}; Unknown Runtime Version)";
}
