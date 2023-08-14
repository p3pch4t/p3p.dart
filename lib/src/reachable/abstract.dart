import 'package:p3p/p3p.dart';

abstract class Reachable {
  List<String> protocols = [];

  Future<P3pError?> reach({
    required P3p p3p,
    required Endpoint endpoint,
    required String message,
    required PublicKey publicKey,
  });
}
