import 'dart:convert';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:hive/hive.dart';
import 'package:p3p/src/chat.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/event.dart';
import 'package:p3p/src/publickey.dart';
import 'package:p3p/src/reachable/local.dart';

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

  Future<void> relayEvents(
      pgp.PrivateKey privatekey, LazyBox<UserInfo> userinfoBox) async {
    if (events.isEmpty) {
      print("no events to relay");
      return;
    }

    final bodyJson = JsonEncoder.withIndent('    ').convert(events);

    final body = await publicKey.encrypt(bodyJson, privatekey);

    for (var endp in endpoint) {
      final resp = await ReachableLocal().reach(
        endp,
        body,
        privatekey,
        userinfoBox,
      );
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