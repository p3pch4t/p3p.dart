import 'dart:convert';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:hive/hive.dart';
import 'package:p3p/src/publickey.dart';
import 'package:p3p/src/userinfo.dart';

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
    LazyBox<PublicKey> publickeyBox,
    LazyBox<UserInfo> userinfoBox,
  ) async {
    // TODO: Plaintext
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
      // TODO: actually process the incoming events.
      // Event.fromJson(elm);
    }
    return userInfo;
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
