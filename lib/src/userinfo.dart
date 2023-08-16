import 'dart:convert';

// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';
import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/local.dart';
import 'package:p3p/src/reachable/relay.dart';

@Entity()
class UserInfo {
  static UserInfo? getUserInfo(P3p p3p, String fingerprint) {
    final pubKey = p3p.publicKeyBox
        .query(PublicKey_.fingerprint.equals(fingerprint))
        .build()
        .findFirst();
    if (pubKey == null) {
      print("pubKey not found - returning empty");
      return null;
    }
    return p3p.userInfoBox
        .query(UserInfo_.dbPublicKey.equals(pubKey.id))
        .build()
        .findFirst()
      ?..init(p3p);
  }

  Future<void> init(P3p p3p) async {}

  UserInfo({
    required this.dbPublicKey,
  });
  @Id()
  int id = 0;

  @Index()
  ToOne<PublicKey> dbPublicKey = ToOne();

  @Transient()
  PublicKey get publicKey => dbPublicKey.target!;
  @Transient()
  set publicKey(PublicKey pk) => dbPublicKey.target = pk;

  @Transient()
  List<Endpoint> get endpoint => dbEndpoint.toList();
  @Transient()
  set endpoint(List<Endpoint> endps) => dbEndpoint
    ..clear()
    ..addAll(endps);

  ToMany<Endpoint> dbEndpoint = ToMany();

  List<Event> getEvents(P3p p3p, PublicKey destination) {
    return p3p.eventBox
        .query(Event_.destinationPublicKey.equals(destination.id))
        .build()
        .find()
        .take(8)
        .toList();
  }

  String? name;

  @Property(type: PropertyType.date)
  DateTime lastMessage = DateTime.fromMicrosecondsSinceEpoch(0);

  @Property(type: PropertyType.date)
  DateTime lastIntroduce = DateTime.fromMicrosecondsSinceEpoch(0);

  /// lastEvent - actually last received event
  @Property(type: PropertyType.date)
  DateTime lastEvent = DateTime.fromMicrosecondsSinceEpoch(0);

  FileStore get fileStore => FileStore(roomFingerprint: publicKey.fingerprint);

  void save(P3p p3p) {
    id = p3p.userInfoBox.put(this);
  }

  Future<List<Message>> getMessages(P3p p3p) async {
    final ret = p3p.messageBox
        .query(Message_.roomFingerprint.equals(publicKey.fingerprint))
        .build()
        .find();
    ret.sort(
      (m1, m2) => m1.dateReceived.difference(m2.dateReceived).inMicroseconds,
    );
    return ret;
  }

  Future<void> addMessage(P3p p3p, Message message) async {
    final msg = p3p.messageBox
        .query(Message_.uuid
            .equals(message.uuid)
            .and(Message_.roomFingerprint.equals(publicKey.fingerprint)))
        .build()
        .findFirst();
    if (msg != null) {
      message.id = msg.id;
    }
    p3p.messageBox.put(message);
    p3p.callOnMessage(message);
  }

  Future<void> relayEvents(P3p p3p, PublicKey publicKey) async {
    // print("relayEvents");
    if (endpoint.isEmpty) {
      print("fixing endpoint by adding ReachableRelay.defaultEndpoints");
      endpoint = ReachableRelay.defaultEndpoints;
    }
    final evts = getEvents(p3p, publicKey);

    if (evts.isEmpty) {
      // print("ignoring because event list is empty");
      return;
    }
    // bool canRelayBulk = true;
    // if (!canRelayBulk) return;

    for (var evt in evts) {
      // print("evts ${evt.id}:${evt.toJson()}");
    }
    final bodyJson = JsonEncoder.withIndent('    ').convert(evts);

    final body = await publicKey.encrypt(bodyJson, p3p.privateKey);

    for (var endp in endpoint) {
      P3pError? resp;
      switch (endp.protocol) {
        case "local" || "locals":
          resp = await ReachableLocal().reach(
            p3p: p3p,
            endpoint: endp,
            message: body,
            publicKey: publicKey,
          );
          break;
        case "relay" || "relays":
          resp = await ReachableRelay().reach(
            p3p: p3p,
            endpoint: endp,
            message: body,
            publicKey: publicKey,
          );
        default:
      }

      if (resp == null) {
        final toDel = <int>[];
        for (var elm in evts) {
          toDel.add(elm.id);
        }
        print("Deleted: $toDel");
        p3p.eventBox.removeMany(toDel);
        save(p3p);
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
    final evts = getEvents(p3p, publicKey);
    final bodyJson = JsonEncoder.withIndent('    ').convert(evts);
    final body = await publicKey.encrypt(bodyJson, p3p.privateKey);
    final toDel = <int>[];
    for (var elm in evts) {
      toDel.add(elm.id);
    }
    p3p.eventBox.removeMany(toDel);
    save(p3p);
    return body;
  }

  Future<void> addEvent(P3p p3p, Event evt) async {
    if (evt.eventType == EventType.introduce) {
      lastIntroduce = DateTime.now();
    }
    // lastEvent = DateTime.now();
    evt.id = p3p.eventBox.put(evt);
    save(p3p);
  }

  static Future<UserInfo?> create(
    P3p p3p,
    String publicKey,
  ) async {
    final pubKey = await PublicKey.create(publicKey);
    if (pubKey == null) return null;
    final ui = UserInfo(
      dbPublicKey: ToOne(target: pubKey),
    )..endpoint = [
        ...ReachableRelay.defaultEndpoints,
      ];
    ui.save(p3p);
    return ui;
  }
}
