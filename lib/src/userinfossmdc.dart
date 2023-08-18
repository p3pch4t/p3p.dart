// import 'package:dart_pg/dart_pg.dart' as pgp;
// import 'package:p3p/p3p.dart';

// /// UserInfoSSMDC
// /// This class should be needed only on the library part of the p3p ecosystem
// /// as it implements UserInfo directly - it can be treated by rest of the code
// /// as equal - but will actually work with multiple destinations...
// /// Why?
// /// For the ease of use - in future projects that will extend p3p ecosystem you
// /// won't need to think about supporting groups because the support is already
// /// there.
// @Entity()
// class UserInfoSSMDC implements UserInfo {
//   UserInfoSSMDC({
//     required this.dbPrivateKey,
//     required this.dbPrivateKeyPasspharse,
//     required this.dbPublicKey,
//   });

//   @override
//   String? name;

//   @override
//   int id = -1;

//   @override
//   Future<void> init(P3p rootP3p) async {
//     _privKey = await getPrivateKey();
//   }

//   String dbPrivateKey;
//   String dbPrivateKeyPasspharse;

//   pgp.PrivateKey? _privKey;

//   Future<pgp.PrivateKey> getPrivateKey() async {
//     if (_privKey != null) return _privKey!;
//     _privKey = await (await pgp.OpenPGP.readPrivateKey(dbPrivateKey))
//         .decrypt(dbPrivateKeyPasspharse);
//     return _privKey!;
//   }

//   Future<pgp.PublicKey> getPublicKey() async {
//     final privKey = await getPrivateKey();
//     return privKey.toPublic;
//   }

//   @override
//   @Index()
//   ToOne<PublicKey> dbPublicKey;

//   @override
//   @Transient()
//   PublicKey get publicKey => dbPublicKey.target!;
//   @override
//   @Transient()
//   set publicKey(PublicKey pk) => dbPublicKey.target = pk;

//   ToMany<UserInfo> users = ToMany();

//   @override
//   Future<void> addEvent(P3p p3p, Event evt) {
//     if (evt.eventType == EventType.introduce) {
//       lastIntroduce = DateTime.now();
//     }
//     for (var ui in users) {
//       evt.encryptPrivkeyArmored = dbPrivateKey;
//       evt.encryptPrivkeyPassowrd = dbPrivateKeyPasspharse;
//       evt.destinationPublicKey = ToOne(target: ui.publicKey);
//       p3p.eventBox.put(evt);
//     }
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> addMessage(P3p p3p, Message message) async {
//     final msg = p3p.messageBox
//         .query(Message_.uuid
//             .equals(message.uuid)
//             .and(Message_.roomFingerprint.equals(publicKey.fingerprint)))
//         .build()
//         .findFirst();
//     if (msg != null) {
//       message.id = msg.id;
//     }
//     p3p.messageBox.put(message);
//     p3p.callOnMessage(message);
//   }

//   @override
//   FileStore get fileStore => FileStore(roomFingerprint: publicKey.fingerprint);

//   @override
//   Future<List<Message>> getMessages(P3p p3p) async {
//     final ret = p3p.messageBox
//         .query(Message_.roomFingerprint.equals(publicKey.fingerprint))
//         .build()
//         .find();
//     ret.sort(
//       (m1, m2) => m1.dateReceived.difference(m2.dateReceived).inMicroseconds,
//     );
//     return ret;
//   }

//   @override
//   Future<void> relayEvents(P3p p3p, PublicKey _) async {
//     for (var user in users) {
//       user.relayEvents(p3p, user.publicKey);
//     }
//   }

//   @override
//   @Deprecated("relayEventsString: doesn't work in SSMDC implementation, due "
//       "to the nature of the requests and the protocol, we are simply returning "
//       "an empty string to not break the compatibility. But refrain from using "
//       "it in future. A better approach needs to be put in place to deliver "
//       "events in a bi-directional way.")
//   Future<String> relayEventsString(P3p p3p) async {
//     print("[ssmdc] relayEventsString: not implemented");
//     return "";
//   }

//   @override
//   void save(P3p p3p) {
//     p3p.userInfoSSMDCBox.put(this);
//   }

//   @override
//   ToMany<Endpoint> dbEndpoint = ToMany();

//   @override
//   @Transient()
//   List<Endpoint> get endpoint => dbEndpoint.toList();
//   @override
//   @Transient()
//   set endpoint(List<Endpoint> endps) => dbEndpoint
//     ..clear()
//     ..addAll(endps);

//   @override
//   @Property(type: PropertyType.date)
//   DateTime lastMessage = DateTime.fromMicrosecondsSinceEpoch(0);

//   @override
//   @Property(type: PropertyType.date)
//   DateTime lastIntroduce = DateTime.fromMicrosecondsSinceEpoch(0);

//   @override
//   @Property(type: PropertyType.date)
//   DateTime lastEvent = DateTime.fromMicrosecondsSinceEpoch(0);

//   @override
//   List<Event> getEvents(P3p p3p, PublicKey destination) {
//     return p3p.eventBox
//         .query(Event_.destinationPublicKey.equals(destination.id))
//         .build()
//         .find();
//   }
// }
