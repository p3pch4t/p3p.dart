import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:p3p/src/p3p_base.dart';

class PublicKey {

  PublicKey({
    required this.fingerprint,
    required this.publickey,
  });
  static Future<PublicKey?> create(
    P3p p3p,
    String armoredPublicKey,
  ) async {
    try {
      final publicKey = await pgp.OpenPGP.readPublicKey(armoredPublicKey);
      publicKey.fingerprint;
      final pubkeyret = PublicKey(
        fingerprint: publicKey.fingerprint,
        publickey: publicKey.armor(),
      );
      await pubkeyret.save(p3p);
      return pubkeyret;
    } catch (e) {
      print(e);
    }
    return null;
  }
  String fingerprint;

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

  Future<void> save(P3p p3p) async {
    await p3p.db.save(this);
  }
}
