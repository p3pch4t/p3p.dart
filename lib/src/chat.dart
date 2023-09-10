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

  static Message? fromEvent(
    Event revt,
    String roomFingerprint, {
    required bool incoming,
  }) {
    if (revt.eventType != EventType.message) return null;
    final evt = revt.data! as EventMessage;
    return Message(
      type: evt.type,
      text: evt.text,
      uuid: revt.uuid,
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
