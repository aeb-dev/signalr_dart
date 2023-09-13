import "dart:io";

import "package:http/http.dart";

extension BaseResponseExtension on BaseResponse {
  void ensureSuccessStatusCode() {
    if (statusCode < 200 || statusCode > 299) {
      throw HttpException(
        "Status code does not indicate success: $statusCode",
      );
    }
  }

  bool get isSuccessStatusCode => statusCode >= 200 || statusCode <= 299;
}
