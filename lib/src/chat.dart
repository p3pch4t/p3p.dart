import 'package:hive/hive.dart';
import 'package:p3p/src/event.dart';

part 'chat.g.dart';

@HiveType(typeId: 5)
class Message {
  Message({
    required this.type,
    required this.text,
    required this.uuid,
  });

  @HiveField(0)
  MessageType type;

  @HiveField(1)
  String text;

  @HiveField(2)
  String uuid;

  static Message? fromEvent(Event evt) {
    if (evt.type == EventType.message) return null;
    return Message(
      type: MessageType.text,
      text: evt.data["text"],
      uuid: evt.uuid,
    );
  }
}

@HiveType(typeId: 6)
enum MessageType {
  @HiveField(0)
  unimplemented,

  @HiveField(1)
  text,
}
