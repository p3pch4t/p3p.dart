class P3pError {
  P3pError({
    required this.code,
    required this.info,
  });
  final int id = -1;
  final int code;
  final String info;
  final DateTime errorDate = DateTime.now();
  @override
  String toString() {
    return '[p3p.dart]: $code: $info';
  }
}
