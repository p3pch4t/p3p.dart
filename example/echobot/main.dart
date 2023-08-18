import 'dart:io';
import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:p3p/p3p.dart';
import 'package:p3p/src/database/drift.dart' as db;
import 'package:path/path.dart' as p;

final fileStorePath = p.join(
  Platform.environment['HOME'] as String,
  '.config/p3p-bots/example_bot',
);

late final P3p p3p;

void main() async {
  // create a private key for authentication.
  final storedPgp = File(p.join(fileStorePath, 'privkey.pgp'));
  if (!await storedPgp.exists()) {
    await storedPgp.create(recursive: true);
    await generatePrivkey(storedPgp);
    print('Privkey generated and stored in ${storedPgp.path}');
    exit(0);
  }
  // create client session
  p3p = await P3p.createSession(
    fileStorePath,
    await storedPgp.readAsString(),
    'passpharse',
    db.DatabaseImplDrift(
      dbFolder: p.join(fileStorePath, 'db-drift'),
    ),
  );

  p3p.onMessageCallback.add(_messageCallback);

  // Print out pgp key to allow others to message us.. actually.
  print((await p3p.getSelfInfo()).publicKey.publickey);

  // start processing new messages
}

void _messageCallback(P3p p3p, Message msg, UserInfo user) {
  p3p.sendMessage(user, "I've received your message: ${msg.text}");
}

Future<void> generatePrivkey(File storedPgp) async {
  final encPgp = await pgp.OpenPGP.generateKey(
      ['simplebot <no-reply@mrcyjanek.net>'], 'passpharse',);
  await storedPgp.writeAsString(encPgp.armor());
}
