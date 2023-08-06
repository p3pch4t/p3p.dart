class P3pError {
  P3pError({
    required this.code,
    required this.info,
  });
  final int code;
  final String info;

  @override
  String toString() {
    return "[p3p.dart]: $code: $info";
  }
}
