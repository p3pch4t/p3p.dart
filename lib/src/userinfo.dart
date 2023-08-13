import 'dart:convert';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:hive/hive.dart';
import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/local.dart';
import 'package:p3p/src/reachable/relay.dart';

part 'userinfo.g.dart';

@HiveType(typeId: 0)
class UserInfo {
  UserInfo({
    required this.publicKey,
    required this.endpoint,
  });
  @HiveField(0)
  PublicKey publicKey;

  @HiveField(1)
  List<Endpoint> endpoint;

  @HiveField(2)
  List<Event> events = [];

  @HiveField(3, defaultValue: null)
  String? name;

  // @HiveField(4)
  // List<Message> messages = [];

  @HiveField(5)
  DateTime lastMessage = DateTime.fromMicrosecondsSinceEpoch(0);

  @HiveField(6)
  DateTime lastIntroduce = DateTime.fromMicrosecondsSinceEpoch(0);

  /// lastEvent - actually last received event
  @HiveField(7)
  DateTime lastEvent = DateTime.fromMicrosecondsSinceEpoch(0);

  FileStore get fileStore => FileStore(roomId: publicKey.fingerprint);

  Future<List<Message>> getMessages(LazyBox<Message> messagesBox) async {
    final ret = <Message>[];
    for (var key in messagesBox.keys) {
      final msg = await messagesBox.get(key);
      if (msg == null) continue;
      if (msg.roomId != publicKey.fingerprint) continue;
      ret.add(msg);
    }
    ret.sort(
      (m1, m2) => m1.dateReceived.difference(m2.dateReceived).inMicroseconds,
    );
    return ret;
  }

  Future<void> addMessage(Message message, LazyBox<Message> messageBox) async {
    await messageBox.put("${message.roomId}.${message.uuid}", message);
  }

  Future<void> relayEvents(
    pgp.PrivateKey privatekey,
    LazyBox<UserInfo> userinfoBox,
    LazyBox<Message> messageBox,
    LazyBox<FileStoreElement> filestoreelementBox,
    String fileStorePath,
  ) async {
    if (events.isEmpty) {
      return;
    }

    final bodyJson = JsonEncoder.withIndent('    ').convert(events);

    final body = await publicKey.encrypt(bodyJson, privatekey);

    for (var endp in endpoint) {
      P3pError? resp;
      switch (endp.protocol) {
        case "local" || "locals":
          resp = await ReachableLocal().reach(
              endp,
              body,
              privatekey,
              userinfoBox,
              messageBox,
              filestoreelementBox,
              publicKey,
              fileStorePath);
          break;
        case "relay" || "relays":
          resp = await ReachableRelay().reach(
              endp,
              body,
              privatekey,
              userinfoBox,
              messageBox,
              filestoreelementBox,
              publicKey,
              fileStorePath);
        default:
      }

      if (resp == null) {
        events = [];
        await userinfoBox.put(publicKey.fingerprint, this);
      }
    }
  }

  /// NOTE: If you call this function event is being set internally as
  /// delivered, it is your problem to hand it over to the user.
  Future<String> relayEventsString(
    pgp.PrivateKey privatekey,
    LazyBox<UserInfo> userinfoBox,
  ) async {
    final bodyJson = JsonEncoder.withIndent('    ').convert(events);

    final body = await publicKey.encrypt(bodyJson, privatekey);

    events = [];
    await userinfoBox.put(publicKey.fingerprint, this);
    return body;
  }

  Future<void> addEvent(Event evt, LazyBox<UserInfo> userinfoBox) async {
    if (evt.type == EventType.introduce) {
      lastIntroduce = DateTime.now();
    }
    events.add(evt);
    await userinfoBox.put(publicKey.fingerprint, this);
  }

  static Future<UserInfo?> create(
    String publicKey,
    LazyBox<UserInfo> userinfoBox,
  ) async {
    final pubKey = await PublicKey.create(publicKey);
    if (pubKey == null) return null;
    final ui = UserInfo(
      publicKey: pubKey,
      endpoint: [
        ...ReachableRelay.defaultEndpoints, // add them so we can reach user
      ],
    );
    await userinfoBox.put(ui.publicKey.fingerprint, ui);
    return ui;
  }
}
