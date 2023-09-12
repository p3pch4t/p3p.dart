/// Class storing information about errors, and their occurence.
class P3pError {
  /// You should call this P3pError to create and write to database an error.
  P3pError({
    required this.code,
    required this.info,
  });

  /// id, -1 to insert new
  final int id = -1;

  /// what is the error code?
  final int code;

  /// details
  final String info;

  /// when did it occur
  final DateTime errorDate = DateTime.now();

  @override
  String toString() {
    return '[p3p.dart]: $code: $info';
  }
}
