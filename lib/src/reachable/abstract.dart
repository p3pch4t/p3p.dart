import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:hive/hive.dart';
import 'package:p3p/p3p.dart';

abstract class Reachable {
  List<String> protocols = [];

  Future<P3pError?> reach(
      Endpoint endpoint,
      String message,
      pgp.PrivateKey privatekey,
      LazyBox<UserInfo> userinfoBox,
      LazyBox<Message> messageBox,
      PublicKey publicKey);
}
