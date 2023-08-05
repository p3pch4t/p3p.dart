import 'package:dart_pg/dart_pg.dart';
import 'package:hive/hive.dart';

part 'publickey.g.dart';

@HiveType(typeId: 1)
class PublicKey {
  static Future<PublicKey> create(String armoredPublicKey) async {
    final publicKey = await OpenPGP.readPublicKey(armoredPublicKey);
    publicKey.fingerprint;
    return PublicKey(
      fingerprint: publicKey.fingerprint,
      publickey: publicKey.armor(),
    );
  }

  PublicKey({
    required this.fingerprint,
    required this.publickey,
  });

  @HiveField(1)
  String fingerprint;

  @HiveField(2)
  String publickey;
}
