import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/error.dart';

abstract class Reachable {
  List<String> protocols = [];

  Future<P3pError?> reach(Endpoint endpoint, String message);
}
