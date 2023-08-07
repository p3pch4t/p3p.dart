import 'dart:convert';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:hive/hive.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/publickey.dart';
import 'package:p3p/src/userinfo.dart';
import 'package:uuid/uuid.dart';

part 'event.g.dart';

@HiveType(typeId: 3)
class Event {
  Event({
    required this.type,
    required this.data,
  });
  @HiveField(0)
  EventType type;

  @HiveField(1)
  Map<String, dynamic> data;

  @HiveField(2)
  String uuid = Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      "type": switch (type) {
        EventType.introduce => "introduce",
        EventType.introduceRequest => "introduce.request",
        EventType.message => "message",
        EventType.unimplemented => "unimplemented",
      },
      "data": data,
    };
  }

  static Event fromJson(Map<String, dynamic> json) {
    return Event(
      type: switch (json["type"] as String) {
        "introduce" => EventType.introduce,
        "introduce.request" => EventType.introduceRequest,
        "message" => EventType.message,
        _ => EventType.unimplemented,
      },
      data: json["data"],
    );
  }

  static Future<UserInfo?> tryProcess(
    String payload,
    pgp.PrivateKey privatekey,
    LazyBox<UserInfo> userinfoBox,
  ) async {
    /// NOTE: we *do* want to process plaintext event: that is introduce
    /// We will use it send and optain publickey for encryption.
    /// NOTE 2: plaintext here may mean http*s* - but not PGP encrypted.
    try {
      final plainText = json.decode(payload) as List<dynamic>;

      for (var evt in plainText) {
        if (evt['type'] == 'introduce' || evt['type'] == "introduce.request") {
          final evtp = Event.fromJson(evt);
          if (evtp.type == EventType.introduce) {
            evtp.processIntroduce(userinfoBox);
          }
          if (evtp.type == EventType.introduceRequest) {
            evtp.processIntroduceRequest(userinfoBox, privatekey);
          }
        }
      }
    } catch (e) {
      // Okay, are not plaintext - this is more than fine.
    }

    final msg = pgp.Message.fromArmored(payload);
    UserInfo? userInfo;
    final data = await pgp.OpenPGP.decrypt(
      msg,
      decryptionKeys: [privatekey],
    );
    if (data.signingKeyIDs.length != 1) {
      return null;
    }
    for (var pbbkey in userinfoBox.keys) {
      final useri = await userinfoBox.get(pbbkey);
      if (useri == null) {
        print("WARN: $pbbkey is null. Plot twist: it shouldn't be.");
        continue;
      }
      if (useri.publicKey.fingerprint
          .endsWith(data.signingKeyIDs.first.toString())) {
        print("Got it: $pbbkey");
        print(useri);
        userInfo = useri;
      }
    }
    final body = data.literalData!.text;
    final jsonBody = json.decode(body) as List<dynamic>;
    for (var elm in jsonBody) {
      final evt = Event.fromJson(elm);
      evt.process(userInfo!, userinfoBox, privatekey);
    }
    return userInfo;
  }

  Future<bool> process(UserInfo userInfo, LazyBox<UserInfo> userinfoBox,
      pgp.PrivateKey privateKey) async {
    switch (type) {
      case EventType.introduce:
        return await processIntroduce(userinfoBox);
      case EventType.introduceRequest:
        return await processIntroduceRequest(userinfoBox, privateKey);
      case EventType.message:
        return false;
      case EventType.unimplemented:
        return false;
    }
  }

  Future<bool> processIntroduce(LazyBox<UserInfo> userinfoBox) async {
    assert(data["publickey"] is String);
    assert(data["endpoint"] is List<String>);
    assert(data["username"] is List<String>);
    final publicKey = await pgp.OpenPGP.readPublicKey(data['publickey']);
    UserInfo? useri = await userinfoBox.get(publicKey.fingerprint);
    useri ??= UserInfo(
        publicKey: await PublicKey.create(data['publickey']),
        endpoint: [],
        name: "unknown - ${DateTime.now()}");
    useri.endpoint = Endpoint.fromStringList(data["endpoint"]);
    useri.name = data["name"];
    await userinfoBox.put(useri.publicKey.fingerprint, useri);
    return true;
  }

  Future<bool> processIntroduceRequest(
    LazyBox<UserInfo> userinfoBox,
    pgp.PrivateKey privateKey,
  ) async {
    final publicKey = await pgp.OpenPGP.readPublicKey(data['publickey']);
    UserInfo? userInfo = await userinfoBox.get(publicKey.fingerprint);
    userInfo ??= UserInfo(
      publicKey: await PublicKey.create(data['publickey']),
      endpoint: [],
      name: "unknown - ${DateTime.now()}",
    );
    userInfo.endpoint = Endpoint.fromStringList(data["endpoint"]);

    userInfo.events.add(
      Event(
        type: EventType.introduce,
        data: {"publickey": privateKey.toPublic.armor()},
      ),
    );
    userinfoBox.put(userInfo.publicKey.fingerprint, userInfo);
    return true;
  }
}

@HiveType(typeId: 4)
enum EventType {
  @HiveField(0)
  unimplemented,

  @HiveField(1)
  introduce,

  @HiveField(2)
  introduceRequest,

  @HiveField(3)
  message,
}
