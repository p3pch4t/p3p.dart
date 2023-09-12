import 'package:p3p/p3p.dart';

/// Message stores information about all a signle message send or received by
/// the user.
class Message {
  /// You may want to use Message.fromEvent instead.
  Message({
    required this.text,
    required this.uuid,
    required this.incoming,
    required this.roomFingerprint,
    this.id = -1,
    this.type = MessageType.unimplemented,
  });

  /// Create Message from Event, (does *NOT* write message to database.)
  Message.fromEvent(
    Event revt,
    this.roomFingerprint, {
    required this.incoming,
  }) {
    // ignore: prefer_asserts_in_initializer_lists
    assert(revt.eventType == EventType.message, 'Invalid message type. oh');
    final evt = revt.data! as EventMessage;
    type = evt.type;
    text = evt.text;
    uuid = revt.uuid;
  }

  /// id in database, -1 to insert new.
  int id = -1;

  /// What type is this message?
  late MessageType type;

  /// Message content
  late String text;

  /// Channel-unique message
  late String uuid;

  /// Did we receive (true) or send (false) this message?
  late bool incoming;

  /// What room does this message belong to?
  late String roomFingerprint;

  /// When was it received.
  DateTime dateReceived = DateTime.now();

  /// get UserInfo of the sender of the message.
  Future<UserInfo> getSender(P3p p3p) async {
    return (await p3p.db.getUserInfo(
      publicKey: await p3p.db.getPublicKey(fingerprint: roomFingerprint),
    ))!;
  }
}

/// All possible message types
enum MessageType {
  /// Default one, in case we don't know what to do with it.
  unimplemented,

  /// Simple text message, displayed as user messages
  text,

  /// Similar to text messages but displayed as service messages - not sent by
  /// anybody in the room
  service,

  /// Not displayed to the user, will get discarded from DB (maybe?)
  hidden,
}
