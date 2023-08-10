import 'dart:convert';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:hive/hive.dart';
import 'package:p3p/src/chat.dart';
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
    print("event.fromJson: $json");
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

    UserInfo? ui;
    try {
      final plainText = json.decode(payload) as List<dynamic>;

      for (var evt in plainText) {
        if (evt is String) {
          print("1");
          final p = await parsePayload(payload, userinfoBox, privatekey);
          ui = p.userInfo;
          for (var evt in p.events) {
            evt.process(ui!, userinfoBox, privatekey);
          }
          continue;
        }
        if (evt['type'] == 'introduce' || evt['type'] == "introduce.request") {
          final evtp = Event.fromJson(evt);
          if (evtp.type == EventType.introduce) {
            evtp.processIntroduce(userinfoBox);
          } else if (evtp.type == EventType.introduceRequest) {
            evtp.processIntroduceRequest(userinfoBox, privatekey);
          } else {}
          continue;
        }
        return ui;
      }
    } catch (e) {
      // Okay, are not plaintext - this is more than fine.
      print("2");
      final parsed = await Event.parsePayload(payload, userinfoBox, privatekey);
      ui = parsed.userInfo;
      for (var element in parsed.events) {
        await element.process(ui!, userinfoBox, privatekey);
      }
    }

    return ui;
  }

  static Future<ParsedPayload> parsePayload(String payload,
      LazyBox<UserInfo> userinfoBox, pgp.PrivateKey privatekey) async {
    final ret = ParsedPayload(userInfo: null, events: []);
    try {
      final src = jsonDecode(payload) as List<dynamic>;
      for (var element in src) {
        print("3");
        final evt =
            (await Event.parsePayload(element, userinfoBox, privatekey));
        ret.events.addAll(evt.events);
        ret.userInfo = evt.userInfo;
      }
      return ret;
    } catch (e) {}
    final msg = pgp.Message.fromArmored(payload);
    UserInfo? userInfo;
    final data = await pgp.OpenPGP.decrypt(
      msg,
      decryptionKeys: [privatekey],
    );
    if (data.signingKeyIDs.length != 1) {
      return ParsedPayload(userInfo: null, events: []);
    }
    for (var pbbkey in userinfoBox.keys) {
      final useri = await userinfoBox.get(pbbkey);
      if (useri == null) {
        print("WARN: $pbbkey is null. Plot twist: it shouldn't be.");
        continue;
      }
      if (useri.publicKey.fingerprint
          .endsWith(data.signingKeyIDs.first.toString())) {
        userInfo = useri;
      }
    }
    final body = data.literalData!.text;
    final jsonBody = json.decode(body) as List<dynamic>;
    for (var elm in jsonBody) {
      ret.events.add(Event.fromJson(elm));
    }
    ret.userInfo = userInfo;
    return ret;
  }

  Future<bool> process(UserInfo userInfo, LazyBox<UserInfo> userinfoBox,
      pgp.PrivateKey privateKey) async {
    print("processing ${toJson().toString()}");
    switch (type) {
      case EventType.introduce:
        return await processIntroduce(userinfoBox);
      case EventType.introduceRequest:
        return await processIntroduceRequest(userinfoBox, privateKey);
      case EventType.message:
        print("event: message");
        return await processMessage(userinfoBox, userInfo);
      case EventType.unimplemented:
        print("event: unimplemented");
        return false;
    }
  }

  Future<bool> processIntroduce(LazyBox<UserInfo> userinfoBox) async {
    print("event: introduce");
    assert(data["publickey"] is String);
    assert(data["endpoint"] is List<String>);
    assert(data["username"] is List<String>);
    final publicKey = await pgp.OpenPGP.readPublicKey(data['publickey']);
    UserInfo? useri = await userinfoBox.get(publicKey.fingerprint);
    if (useri != null) {
      useri.refresh(userinfoBox);
    }
    useri ??= UserInfo(
        publicKey: (await PublicKey.create(data['publickey']))!,
        endpoint: [],
        name: "unknown - ${DateTime.now()}");
    useri.lastMessage = DateTime.now();
    useri.endpoint = Endpoint.fromStringList(data["endpoint"]);
    useri.name = data["name"];
    await userinfoBox.put(useri.publicKey.fingerprint, useri);
    return true;
  }

  Future<bool> processIntroduceRequest(
    LazyBox<UserInfo> userinfoBox,
    pgp.PrivateKey privateKey,
  ) async {
    print("event: introduce.request");
    final publicKey = await pgp.OpenPGP.readPublicKey(data['publickey']);
    UserInfo? userInfo = await userinfoBox.get(publicKey.fingerprint);
    userInfo ??= UserInfo(
      publicKey: (await PublicKey.create(data['publickey']))!,
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
    await userinfoBox.put(userInfo.publicKey.fingerprint, userInfo);
    return true;
  }

  Future<bool> processMessage(
      LazyBox<UserInfo> userinfoBox, UserInfo userInfo) async {
    print("event: processMessage");
    userInfo.messages.add(
      Message(
        type: MessageType.text,
        text: data["text"].toString(),
        uuid: uuid,
        incoming: true,
      ),
    );
    await userinfoBox.put(userInfo.publicKey.fingerprint, userInfo);
    print("totalMessages:${userInfo.messages.length}");
    print("fingerprint: ${userInfo.publicKey.fingerprint}");
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

class ParsedPayload {
  ParsedPayload({
    required this.userInfo,
    required this.events,
  });
  UserInfo? userInfo;
  List<Event> events;
}

class EventIntroduceRequest {
  EventIntroduceRequest({
    required this.publickey,
    required this.endpoint,
  });

  final pgp.PublicKey publickey;
  final List<Endpoint> endpoint;

  Map<String, dynamic> toJson() {
    return {
      "publickey": publickey.armor(),
      "endpoint": endpoint.toString(), // tostring
    };
  }
}

class EventMessage {
  EventMessage({
    required this.text,
  });
  String text;

  Map<String, dynamic> toJson() {
    return {
      "text": text,
    };
  }
}
