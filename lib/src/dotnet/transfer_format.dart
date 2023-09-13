enum TransferFormat {
  binary(1),
  text(2),
  ;

  final int value;

  const TransferFormat(this.value);

  @override
  String toString() {
    switch (this) {
      case TransferFormat.binary:
        return "Binary";
      case TransferFormat.text:
        return "Text";
    }
  }
}
