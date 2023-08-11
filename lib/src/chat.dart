import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:p3p/src/event.dart';

part 'chat.g.dart';

@HiveType(typeId: 5)
class Message {
  Message({
    required this.type,
    required this.text,
    required this.uuid,
    required this.incoming,
    required this.roomId,
  });

  @HiveField(0)
  MessageType type;

  @HiveField(1)
  String text;

  @HiveField(2)
  String uuid;

  @HiveField(3)
  bool incoming;

  @HiveField(4)
  String roomId;

  static Message? fromEvent(Event evt, bool incoming, String roomId) {
    if (evt.type == EventType.message) return null;
    return Message(
      type: MessageType.text,
      text: evt.data["text"],
      uuid: evt.uuid,
      incoming: incoming,
      roomId: roomId,
    );
  }

  String debug() {
    return JsonEncoder.withIndent('    ').convert({
      "type": type.toString(),
      "text": text,
      "uuid": uuid,
      "incoming": incoming,
      "roomId": roomId,
    });
  }
}

@HiveType(typeId: 6)
enum MessageType {
  @HiveField(0)
  unimplemented,

  @HiveField(1)
  text,
}
