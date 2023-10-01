import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:p3p/src/p3p_base.dart';

/// Stores PublicKey information - unique for each user
class PublicKey {
  /// Don't create manually, use PublicKey.create instead
  PublicKey({
    required this.fingerprint,
    required this.publickey,
  });

  int id = -1;

  /// Create publickey from armored string
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
      pubkeyret.id = await p3p.db.save(pubkeyret);
      return pubkeyret;
    } catch (e) {
      print(e);
    }
    return null;
  }

  /// Key's fingerprint
  final String fingerprint;

  /// armored publickey
  final String publickey;

  /// encrypt for this publickey and sign by privatekey
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
