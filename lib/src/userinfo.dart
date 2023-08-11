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
    required this.name,
  });
  @HiveField(0)
  PublicKey publicKey;

  @HiveField(1)
  List<Endpoint> endpoint;

  @HiveField(2)
  List<Event> events = [];

  @HiveField(3)
  String name;

  // @HiveField(4)
  // List<Message> messages = [];
  Future<List<Message>> getMessages(LazyBox<Message> messagesBox) async {
    final ret = <Message>[];
    for (var key in messagesBox.keys) {
      final msg = await messagesBox.get(key);
      if (msg == null) continue;
      if (msg.roomId != publicKey.fingerprint) continue;
      ret.add(msg);
    }
    return ret;
  }

  Future<void> addMessage(Message message, LazyBox<Message> messageBox) async {
    await messageBox.put("${message.roomId}.${message.uuid}", message);
  }

  @HiveField(5)
  DateTime lastMessage = DateTime.fromMicrosecondsSinceEpoch(0);

  static Future<UserInfo?> create(
    String publicKey,
    LazyBox<UserInfo> userinfoBox,
  ) async {
    final pubKey = await PublicKey.create(publicKey);
    if (pubKey == null) return null;
    final ui = UserInfo(
      publicKey: pubKey,
      endpoint: [
        Endpoint(protocol: "relay", host: "mrcyjanek.net:3847", extra: ""),
      ],
      name: "unknown [relay]",
    );
    await userinfoBox.put(ui.publicKey.fingerprint, ui);
    return ui;
  }

  Future<void> relayEvents(pgp.PrivateKey privatekey,
      LazyBox<UserInfo> userinfoBox, LazyBox<Message> messageBox) async {
    if (events.isEmpty) {
      print("no events to relay");
      return;
    }

    final bodyJson = JsonEncoder.withIndent('    ').convert(events);

    final body = await publicKey.encrypt(bodyJson, privatekey);

    for (var endp in endpoint) {
      P3pError? resp;
      switch (endp.protocol) {
        case "local" || "locals":
          resp = await ReachableLocal().reach(
              endp, body, privatekey, userinfoBox, messageBox, publicKey);
          break;
        case "relay" || "relays":
          resp = await ReachableRelay().reach(
              endp, body, privatekey, userinfoBox, messageBox, publicKey);
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
    events.add(evt);
    await userinfoBox.put(publicKey.fingerprint, this);
  }
}
