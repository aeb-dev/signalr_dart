import "dart:io";

extension PlatformExtensions on Platform {
  static String get lineSeparator => Platform.isWindows ? "\r\n" : "\n";
}
