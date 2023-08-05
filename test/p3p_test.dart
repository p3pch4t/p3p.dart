import 'package:p3p/p3p.dart';
import 'package:test/test.dart';

void main() {
  group('library v1', () async {
    final p3p = await P3p.createSession('store', 'sessionName');

    test('getSelfInfo', () => p3p.getSelfInfo());
    test('sendMessage', () => p3p.sendMessage());
    test('getChats', () => p3p.getChats());
    test('getUnread', () => p3p.getUnread());
  });
}
