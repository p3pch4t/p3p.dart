import 'package:dart_pg/dart_pg.dart';
import 'package:p3p/p3p.dart';
import 'package:test/test.dart';

const privateKeyPassword = "test";

void main() async {
  final userID = ['testUser01', '<test@test.test>'].join(' ');
  final testPk = await OpenPGP.generateKey(
    [userID],
    privateKeyPassword,
    rsaKeySize: RSAKeySize.s2048,
  );
  final p3p = await P3p.createSession(
    '/tmp/p3p_test_store',
    testPk.armor(),
    privateKeyPassword,
  );

  print("testing as: ${testPk.fingerprint} (${testPk.keyID})");
  group('library v1', () {
    test('getSelfInfo', () => p3p.getSelfInfo());
    test('sendMessage', () async {
      final userInfo = await p3p.getSelfInfo();
      final err = await p3p.sendMessage(userInfo, "test");
      if (err != null) {
        fail(err.toString());
      }
    });
    test('messages', () async {
      final userInfo = await p3p.getSelfInfo();
      final msgs = await userInfo.getMessages(p3p.messageBox);
      print(msgs.length);
      for (var element in msgs) {
        print('msg: ${element.text}');
      }
      for (var k in p3p.messageBox.keys) {
        final msg = await p3p.messageBox.get(k);
        print(msg?.debug());
      }
    });
  });
}
