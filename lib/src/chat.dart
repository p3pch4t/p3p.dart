import 'package:p3p/p3p.dart';

class Message {
  Message({
    required this.text,
    required this.uuid,
    required this.incoming,
    required this.roomFingerprint,
    this.id = -1,
    this.type = MessageType.unimplemented,
  });
  int id = -1;
  MessageType type;
  String text;
  String uuid;
  bool incoming;
  String roomFingerprint;
  DateTime dateReceived = DateTime.now();

  Future<UserInfo> getSender(P3p p3p) async {
    return (await p3p.db.getUserInfo(
      publicKey: await p3p.db.getPublicKey(fingerprint: roomFingerprint),
    ))!;
  }

  Future<void> save(P3p p3p) async {
    await p3p.db.save(this);
  }

  static Message? fromEvent(Event evt, bool incoming, String roomFingerprint) {
    if (evt.eventType != EventType.message) return null;
    return Message(
      type: switch (evt.data['type'] as String?) {
        null || 'text' => MessageType.text,
        'service' => MessageType.service,
        _ => MessageType.unimplemented,
      },
      text: evt.data['text'] as String,
      uuid: evt.uuid,
      incoming: incoming,
      roomFingerprint: roomFingerprint,
    );
  }
}

enum MessageType {
  unimplemented,
  text,
  service,
  hidden,
}
