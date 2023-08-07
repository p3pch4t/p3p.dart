import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:hive/hive.dart';

part 'publickey.g.dart';

@HiveType(typeId: 1)
class PublicKey {
  static Future<PublicKey> create(String armoredPublicKey) async {
    final publicKey = await pgp.OpenPGP.readPublicKey(armoredPublicKey);
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

  Future<String> encrypt(String data, pgp.PrivateKey privatekey) async {
    print("publickey.dart: createTextMessage ($data)");
    pgp.Message msg = pgp.Message.createTextMessage(data);

    print("publickey.dart: encrypt");
    msg = await msg.encrypt(
      encryptionKeys: [
        await pgp.OpenPGP.readPublicKey(publickey),
      ],
    );
    print("publickey.dart: sign");
    msg = await msg.sign(
      [privatekey],
    );
    print("publickey.dart: armor");
    return msg.armor();
  }
}
