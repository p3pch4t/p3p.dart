import 'dart:convert';

import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/local.dart';
import 'package:p3p/src/reachable/relay.dart';

class UserInfo {
  UserInfo({
    required this.publicKey,
    required this.endpoint,
    this.id = -1,
    this.name,
  });
  int id = -1;
  PublicKey publicKey;
  List<Endpoint> endpoint;
  Future<List<Event>> getEvents(P3p p3p, PublicKey destination) async {
    return await p3p.db.getEvents(destinationPublicKey: destination);
  }

  String? name;
  DateTime lastMessage = DateTime.fromMicrosecondsSinceEpoch(0);
  DateTime lastIntroduce = DateTime.fromMicrosecondsSinceEpoch(0);
  DateTime lastEvent = DateTime.fromMicrosecondsSinceEpoch(0);

  FileStore get fileStore => FileStore(roomFingerprint: publicKey.fingerprint);
  Future<void> init(P3p p3p) async {}

  Future<void> save(P3p p3p) async {
    await p3p.db.save(this);
  }

  Future<List<Message>> getMessages(P3p p3p) async {
    final ret =
        await p3p.db.getMessageList(roomFingerprint: publicKey.fingerprint);
    ret.sort(
      (m1, m2) => m1.dateReceived.difference(m2.dateReceived).inMicroseconds,
    );
    return ret;
  }

  Future<void> addMessage(P3p p3p, Message message) async {
    final msg = await p3p.db
        .getMessage(uuid: message.uuid, roomFingerprint: publicKey.fingerprint);
    if (msg != null) {
      message.id = msg.id;
    }
    await p3p.db.save(message);
    await p3p.callOnMessage(message);
  }

  Future<void> relayEvents(P3p p3p, PublicKey publicKey) async {
    print('relayEvents');
    if (endpoint.isEmpty) {
      print('fixing endpoint by adding ReachableRelay.defaultEndpoints');
      endpoint = ReachableRelay.defaultEndpoints;
    }
    final evts = await getEvents(p3p, publicKey);

    if (evts.isEmpty) {
      return;
    }
    // bool canRelayBulk = true;
    // if (!canRelayBulk) return;

    // for (var evt in evts) {
    //   print("evts ${evt.id}:${evt.toJson()}");
    // }
    final bodyJson = const JsonEncoder.withIndent('    ').convert(evts);

    final body = await publicKey.encrypt(bodyJson, p3p.privateKey);

    for (final endp in endpoint) {
      P3pError? resp;
      switch (endp.protocol) {
        case 'local' || 'locals':
          resp = await ReachableLocal().reach(
            p3p: p3p,
            endpoint: endp,
            message: body,
            publicKey: publicKey,
          );
        case 'relay' || 'relays':
          resp = await ReachableRelay().reach(
            p3p: p3p,
            endpoint: endp,
            message: body,
            publicKey: publicKey,
          );
        default:
      }

      if (resp == null) {
        for (final elm in evts) {
          await p3p.db.remove(elm);
        }
      } else {
        print(resp);
      }
    }
  }

  @Deprecated(
      'NOTE: If you call this function event is being set internally as '
      'delivered, it is your problem to hand it over to the user. '
      'desired location. \n'
      'For this reason this is released as deprecated - to discourage '
      'usage. ')
  Future<String> relayEventsString(
    P3p p3p,
  ) async {
    final evts = await getEvents(p3p, publicKey);
    final bodyJson = const JsonEncoder.withIndent('    ').convert(evts);
    final body = await publicKey.encrypt(bodyJson, p3p.privateKey);
    final toDel = <int>[];
    for (final elm in evts) {
      await p3p.db.remove(elm);
    }
    return body;
  }

  Future<void> addEvent(P3p p3p, Event evt) async {
    if (evt.eventType == EventType.introduce) {
      lastIntroduce = DateTime.now();
    }
    lastEvent = DateTime.now();
    evt.destinationPublicKey = publicKey;
    await evt.save(p3p);
    await save(p3p);
  }

  static Future<UserInfo?> create(
    P3p p3p,
    String publicKey,
  ) async {
    final pubKey = await PublicKey.create(p3p, publicKey);
    if (pubKey == null) return null;
    final ui = UserInfo(
      publicKey: pubKey,
      endpoint: [
        ...ReachableRelay.defaultEndpoints,
      ],
    );
    await ui.save(p3p);
    return ui;
  }
}
