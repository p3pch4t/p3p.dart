import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:hive/hive.dart';
import 'package:p3p/src/chat.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/filestore.dart';
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
        EventType.fileRequest => "file.request",
        EventType.file => "file",
        EventType.unimplemented => "unimplemented",
      },
      "data": data,
      "uuid": uuid,
    };
  }

  static Event fromJson(Map<String, dynamic> json) {
    return Event(
      type: switch (json["type"] as String) {
        "introduce" => EventType.introduce,
        "introduce.request" => EventType.introduceRequest,
        "message" => EventType.message,
        "file.request" => EventType.fileRequest,
        "file" => EventType.file,
        _ => EventType.unimplemented,
      },
      data: json["data"],
    )..uuid = json["uuid"];
  }

  static Future<UserInfo?> tryProcess(
      String payload,
      pgp.PrivateKey privatekey,
      LazyBox<UserInfo> userinfoBox,
      LazyBox<Message> messageBox,
      LazyBox<FileStoreElement> filestoreelementBox,
      String fileStorePath) async {
    /// NOTE: we *do* want to process plaintext event: that is introduce
    /// We will use it send and optain publickey for encryption.
    /// NOTE 2: plaintext here may mean http*s* - but not PGP encrypted.

    UserInfo? ui;
    try {
      final plainText = json.decode(payload) as List<dynamic>;

      for (var evt in plainText) {
        if (evt is String) {
          final p = await parsePayload(payload, userinfoBox, privatekey);
          ui = p.userInfo;
          for (var evt in p.events) {
            evt.process(ui!, userinfoBox, messageBox, filestoreelementBox,
                privatekey, fileStorePath);
          }
          continue;
        }
        if (evt['type'] == 'introduce' || evt['type'] == "introduce.request") {
          final evtp = Event.fromJson(evt);
          if (evtp.type == EventType.introduce) {
            evtp.processIntroduce(
                userinfoBox, filestoreelementBox, fileStorePath);
          } else if (evtp.type == EventType.introduceRequest) {
            evtp.processIntroduceRequest(
                userinfoBox, filestoreelementBox, privatekey);
          } else {}
          continue;
        }
        return ui;
      }
    } catch (e) {
      // Okay, are not plaintext - this is more than fine.
      final parsed = await Event.parsePayload(payload, userinfoBox, privatekey);
      ui = parsed.userInfo;
      for (var element in parsed.events) {
        await element.process(ui!, userinfoBox, messageBox, filestoreelementBox,
            privatekey, fileStorePath);
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
        final evt =
            (await Event.parsePayload(element, userinfoBox, privatekey));
        ret.events.addAll(evt.events);
        ret.userInfo = evt.userInfo;
        print("new event from:${ret.userInfo?.publicKey.fingerprint}");
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

  Future<bool> process(
      UserInfo userInfo,
      LazyBox<UserInfo> userinfoBox,
      LazyBox<Message> messageBox,
      LazyBox<FileStoreElement> filestoreelementBox,
      pgp.PrivateKey privateKey,
      String fileStorePath) async {
    print("processing..");
    JsonEncoder.withIndent('    ')
        .convert(toJson())
        .split("\n")
        .forEach((element) {
      print(element); // I hate the fact that flutter cuts the logs.
    });
    switch (type) {
      case EventType.introduce:
        return await processIntroduce(
            userinfoBox, filestoreelementBox, fileStorePath);
      case EventType.introduceRequest:
        return await processIntroduceRequest(
            userinfoBox, filestoreelementBox, privateKey);
      case EventType.message:
        print("event: message");
        return await processMessage(userinfoBox, messageBox, userInfo);
      case EventType.fileRequest:
        return await processFileRequest(
            userinfoBox, messageBox, filestoreelementBox, userInfo);
      case EventType.file:
      case EventType.unimplemented:
        print("event: unimplemented");
        return false;
    }
  }

  Future<bool> processIntroduce(
    LazyBox<UserInfo> userinfoBox,
    LazyBox<FileStoreElement> filestoreelementBox,
    String fileStorePath,
  ) async {
    print("event: introduce");
    if (data["publickey"] is! String ||
        data["endpoint"] is! List<dynamic> /* string actually.. */ ||
        data["username"] is! String ||
        data["filestore"] is! List<dynamic>) {
      print("invalid event, ignoring");
      print("publickey: ${data["publickey"].runtimeType}");
      print("endpoint: ${data["endpoint"].runtimeType}");
      print("username: ${data["username"].runtimeType}");
      print("filestore: ${data["filestore"].runtimeType}");
      return true;
    }
    final publicKey = await pgp.OpenPGP.readPublicKey(data['publickey']);
    UserInfo? useri = await userinfoBox.get(publicKey.fingerprint);
    useri ??= UserInfo(
      publicKey: (await PublicKey.create(data['publickey']))!,
      endpoint: [],
    );
    useri.lastMessage = DateTime.now();
    final eList = <String>[];
    data["endpoint"].forEach((elm) {
      eList.add(elm.toString());
    });
    useri.endpoint = Endpoint.fromStringList(eList);
    useri.name = data["username"];
    final elms = await useri.fileStore.getFileStoreElement(filestoreelementBox);
    for (var elm in data["filestore"]) {
      bool updated = false;
      for (var elmStored in elms) {
        if (elmStored.uuid != elm["uuid"]) continue;
        final modTime = DateTime.fromMicrosecondsSinceEpoch(elm["modifyTime"]);
        if (elmStored.modifyTime.isBefore(modTime)) {
          updated = true;
          elmStored.path = elm["path"];
          elmStored.sha512sum = elm["sha512sum"];
          elmStored.sizeBytes = elm["sizeBytes"];
          elmStored.isDeleted = elm["isDeleted"];
          elmStored.modifyTime = modTime;
          await elmStored.save(
            filestoreelementBox,
            userinfoBox,
            useri.publicKey.fingerprint,
            noUpdate: true,
          );
        }
      }
      if (!updated) {
        await useri.fileStore.putFileStoreElement(
            filestoreelementBox,
            userinfoBox,
            null,
            elm["sha512sum"],
            elm["sizeBytes"],
            elm["path"],
            fileStorePath,
            uuid: elm["uuid"]);
      }
    }

    await userinfoBox.put(useri.publicKey.fingerprint, useri);
    return true;
  }

  Future<bool> processIntroduceRequest(
    LazyBox<UserInfo> userinfoBox,
    LazyBox<FileStoreElement> filestoreelementBox,
    pgp.PrivateKey privateKey,
  ) async {
    print("event: introduce.request");
    final publicKey = await pgp.OpenPGP.readPublicKey(data['publickey']);
    UserInfo? userInfo = await userinfoBox.get(publicKey.fingerprint);
    final selfUser = await userinfoBox.get(privateKey.fingerprint);
    if (selfUser == null) {
      print("NO SELFUSER - fp ${privateKey.fingerprint}");
    }
    userInfo ??= UserInfo(
      publicKey: (await PublicKey.create(data['publickey']))!,
      endpoint: [],
    );
    userInfo.endpoint = Endpoint.fromStringList(data["endpoint"]);

    userInfo.events.add(
      Event(
        type: EventType.introduce,
        data: EventIntroduce(
          endpoint: selfUser!.endpoint,
          fselm:
              await userInfo.fileStore.getFileStoreElement(filestoreelementBox),
          publickey: privateKey.toPublic,
          username: selfUser.name ?? 'unknown username (ir)',
        ).toJson(),
      ),
    );
    await userinfoBox.put(userInfo.publicKey.fingerprint, userInfo);
    return true;
  }

  Future<bool> processMessage(LazyBox<UserInfo> userinfoBox,
      LazyBox<Message> messageBox, UserInfo userInfo) async {
    print("event: processMessage");
    assert(type == EventType.message);
    await userInfo.addMessage(
        Message.fromEvent(this, true, userInfo.publicKey.fingerprint)!,
        messageBox);
    return true;
  }

  Future<bool> processFileRequest(
    LazyBox<UserInfo> userinfoBox,
    LazyBox<Message> messageBox,
    LazyBox<FileStoreElement> filestoreelementBox,
    UserInfo userInfo,
  ) async {
    assert(type == EventType.fileRequest);
    final freq = EventFileRequest.fromEvent(this);
    final file = await filestoreelementBox
        .get('${userInfo.publicKey.fingerprint}.${freq.uuid}');
    if (file == null) return true; // we don't have that file
    if (freq.start == null) {}
    final sendStart = freq.start ?? 0;
    final sendEnd =
        min(file.sizeBytes, freq.end ?? (sendStart + 16 * 1024 * 1024));
    final bytes = await file.file.openRead(sendStart, sendEnd).first;

    userInfo.addEvent(
        Event(
          type: EventType.file,
          data: EventFile(
            bytes: Uint8List.fromList(bytes),
            end: sendEnd,
            start: sendStart,
            uuid: freq.uuid,
          ).toJson(),
        ),
        userinfoBox);
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

  @HiveField(4)
  fileRequest,

  @HiveField(5)
  file,
}

class ParsedPayload {
  ParsedPayload({
    required this.userInfo,
    required this.events,
  });
  UserInfo? userInfo;
  List<Event> events;
}

class EventIntroduce {
  EventIntroduce({
    required this.publickey,
    required this.endpoint,
    required this.fselm,
    required this.username,
  });

  final pgp.PublicKey publickey;
  final List<Endpoint> endpoint;
  final List<FileStoreElement> fselm;
  final String username;

  Map<String, dynamic> toJson() {
    List<String> endpoints = [];
    for (var elm in endpoint) {
      endpoints.add(elm.toString());
    }
    return {
      "publickey": publickey.armor(),
      "endpoint": endpoints,
      "filestore": fselm,
      "username": username,
    };
  }
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
    required this.type,
  });
  String text;
  MessageType type;

  Map<String, dynamic> toJson() {
    return {
      "text": text,
      "type": switch (type) {
        MessageType.unimplemented => null,
        MessageType.text => "text",
        MessageType.service => "service",
        MessageType.hidden => "hidden",
      }
    };
  }
}

class EventFileRequest {
  EventFileRequest({
    required this.uuid,
    this.start,
    this.end,
  });
  String uuid;
  int? start;
  int? end;
  Map<String, dynamic> toJson() {
    return {
      "uuid": uuid,
      "start": start,
      "end": end,
    };
  }

  static EventFileRequest fromEvent(Event event) {
    return EventFileRequest(
      uuid: event.data["uuid"],
      start: event.data["start"],
      end: event.data["end"],
    );
  }
}

class EventFile {
  EventFile({
    required this.uuid,
    required this.start,
    required this.end,
    required this.bytes,
  });
  String uuid;
  int start;
  int end;
  Uint8List bytes;

  Map<String, dynamic> toJson() {
    return {
      "uuid": uuid,
      "start": start,
      "end": end,
      "bytes": base64.encode(bytes),
    };
  }

  static EventFile fromJson(Map<String, dynamic> json) {
    return EventFile(
      uuid: json["uuid"],
      start: json["start"],
      end: json["end"],
      bytes: base64.decode(json["bytes"]),
    );
  }
}
