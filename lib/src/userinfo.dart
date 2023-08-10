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

  @HiveField(4)
  List<Message> messages = [];

  @HiveField(5)
  DateTime lastMessage = DateTime.fromMicrosecondsSinceEpoch(0);

  Future<void> refresh(LazyBox<UserInfo> userinfoBox) async {
    final ui = (await userinfoBox.get(publicKey.fingerprint));
    if (ui == null) return;
    publicKey = ui.publicKey;
    endpoint = ui.endpoint;
    events = ui.events;
    name = ui.name;
    messages = ui.messages;
    lastMessage = ui.lastMessage;
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
        Endpoint(protocol: "relay", host: "mrcyjanek.net:3847", extra: ""),
      ],
      name: "unknown [relay]",
    );
    await userinfoBox.put(ui.publicKey.fingerprint, ui);
    return ui;
  }

  Future<void> relayEvents(
      pgp.PrivateKey privatekey, LazyBox<UserInfo> userinfoBox) async {
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
          resp = await ReachableLocal()
              .reach(endp, body, privatekey, userinfoBox, publicKey);
          break;
        case "relay" || "relays":
          resp = await ReachableRelay()
              .reach(endp, body, privatekey, userinfoBox, publicKey);
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
