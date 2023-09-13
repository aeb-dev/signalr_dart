import "dart:convert";

class BasicCredential {
  final String username;
  final String password;

  const BasicCredential(
    this.username,
    this.password,
  );

  String encodedValue() {
    String b64 = base64Encode(utf8.encode("$username:$password"));
    return "Basic $b64";
  }

  String get userInfo => "$username:$password";
}
