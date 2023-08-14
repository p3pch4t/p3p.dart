import 'package:p3p/p3p.dart';

@Entity()
class Message {
  Message({
    this.type = MessageType.unimplemented,
    required this.text,
    required this.uuid,
    required this.incoming,
    required this.roomFingerprint,
  });

  @Id()
  int id = 0;

  @Transient()
  MessageType type;

  set dbType(int msgType) => type = MessageType.values[msgType];
  int get dbType => type.index;

  String text;

  @Unique(onConflict: ConflictStrategy.replace)
  String uuid;

  bool incoming;

  @Index()
  String roomFingerprint;

  @Property(type: PropertyType.date)
  DateTime dateReceived = DateTime.now();

  UserInfo getSender(P3p p3p) {
    return p3p.getUserInfo(roomFingerprint)!;
  }

  static Message? fromEvent(Event evt, bool incoming, String roomFingerprint) {
    if (evt.eventType != EventType.message) return null;
    return Message(
      type: switch (evt.data["type"] as String?) {
        null || "text" => MessageType.text,
        "service" => MessageType.service,
        _ => MessageType.unimplemented,
      },
      text: evt.data["text"],
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
