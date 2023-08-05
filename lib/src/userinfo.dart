import 'package:hive/hive.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/publickey.dart';

part 'userinfo.g.dart';

@HiveType(typeId: 0)
class UserInfo {
  UserInfo({
    required this.publicKey,
    required this.endpoint,
  });
  @HiveField(0)
  PublicKey publicKey;

  @HiveField(1)
  Endpoint endpoint;
}
