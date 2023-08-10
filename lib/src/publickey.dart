import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:hive/hive.dart';

part 'publickey.g.dart';

@HiveType(typeId: 1)
class PublicKey {
  static Future<PublicKey?> create(String armoredPublicKey) async {
    try {
      final publicKey = await pgp.OpenPGP.readPublicKey(armoredPublicKey);
      publicKey.fingerprint;
      return PublicKey(
        fingerprint: publicKey.fingerprint,
        publickey: publicKey.armor(),
      );
    } catch (e) {
      print(e);
    }
    return null;
  }

  PublicKey({
    required this.fingerprint,
    required this.publickey,
  });

  @HiveField(1)
  String fingerprint;

  @HiveField(2)
  String publickey;

  Future<String> encrypt(String data, pgp.PrivateKey privatekey) async {
    final pubkey = await pgp.OpenPGP.readPublicKey(publickey);
    final msg = await pgp.OpenPGP.encrypt(
      pgp.Message.createTextMessage(data),
      encryptionKeys: [
        pubkey,
      ],
      signingKeys: [
        privatekey,
      ],
    );
    return msg.armor();
  }
}
