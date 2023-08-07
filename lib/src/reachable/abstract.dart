import 'package:dart_pg/dart_pg.dart';
import 'package:hive/hive.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/error.dart';
import 'package:p3p/src/userinfo.dart';

abstract class Reachable {
  List<String> protocols = [];

  Future<P3pError?> reach(
    Endpoint endpoint,
    String message,
    PrivateKey privatekey,
    LazyBox<UserInfo> userinfoBox,
  );
}
