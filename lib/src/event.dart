import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/relay.dart';
import 'package:uuid/uuid.dart';

@Entity()
class Event {
  Event({
    this.eventType,
    this.encryptPrivkeyArmored,
    this.encryptPrivkeyPassowrd,
    required this.destinationPublicKey,
  });
  @Id()
  int id = 0;

  @Transient()
  EventType? eventType;

  String? encryptPrivkeyArmored;
  String? encryptPrivkeyPassowrd;

  ToOne<PublicKey> destinationPublicKey = ToOne();

  set dbType(int i) => eventType = EventType.values[i];
  int get dbType => eventType!.index;

  @Transient()
  Map<String, dynamic> get data {
    final decoded = json.decode(dbData);
    if (decoded is String) return {};
    return decoded;
  }

  @Transient()
  set data(Map<String, dynamic> nData) => dbData = json.encode(nData);

  String dbData = "{}";

  String uuid = Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      "type": switch (eventType) {
        EventType.introduce => "introduce",
        EventType.introduceRequest => "introduce.request",
        EventType.message => "message",
        EventType.fileRequest => "file.request",
        EventType.file => "file",
        EventType.unimplemented => "unimplemented",
        null => "unimplemented",
      },
      "data": data,
      "uuid": uuid,
    };
  }

  static Event fromJson(Map<String, dynamic> json) {
    return Event(
      eventType: switch (json["type"] as String) {
        "introduce" => EventType.introduce,
        "introduce.request" => EventType.introduceRequest,
        "message" => EventType.message,
        "file.request" => EventType.fileRequest,
        "file" => EventType.file,
        _ => EventType.unimplemented,
      },
      destinationPublicKey: ToOne(),
    )
      ..data = json["data"]
      ..uuid = json["uuid"];
  }

  static Future<UserInfo?> tryProcess(
    P3p p3p,
    String payload,
  ) async {
    /// NOTE: we *do* want to process plaintext event: that is introduce
    /// We will use it send and optain publickey for encryption.
    /// NOTE 2: plaintext here may mean http*s* - but not PGP encrypted.

    UserInfo? ui;
    try {
      final plainText = json.decode(payload) as List<dynamic>;

      for (var evt in plainText) {
        if (evt is String) {
          final p = await parsePayload(payload, p3p);
          ui = p.userInfo;
          for (var evt in p.events) {
            evt.process(ui!, p3p);
          }
          continue;
        }
        if (evt['type'] == 'introduce' || evt['type'] == "introduce.request") {
          final evtp = Event.fromJson(evt);
          if (evtp.eventType == EventType.introduce) {
            evtp.processIntroduce(p3p);
          } else if (evtp.eventType == EventType.introduceRequest) {
            evtp.processIntroduceRequest(p3p);
          } else {}
          continue;
        }
        return ui;
      }
    } catch (e) {
      // Okay, are not plaintext - this is more than fine.
      final parsed = await Event.parsePayload(payload, p3p);
      ui = parsed.userInfo;
      for (var element in parsed.events) {
        if (ui == null) {
          tryProcess(p3p, payload);
        } else {
          await element.process(ui, p3p);
        }
      }
    }

    return ui;
  }

  static Future<ParsedPayload> parsePayload(String payload, P3p p3p) async {
    final ret = ParsedPayload(userInfo: null, events: []);
    try {
      final src = jsonDecode(payload) as List<dynamic>;
      for (var element in src) {
        final evt = (await Event.parsePayload(element, p3p));
        ret.events.addAll(evt.events);
        ret.userInfo = evt.userInfo;
        print("new event from:${ret.userInfo?.publicKey.fingerprint}");
      }
      return ret;
    } catch (e) {
      // we received a full-encrypted event. This is even better.
    }
    final msg = pgp.Message.fromArmored(payload);
    UserInfo? userInfo;
    final data = await pgp.OpenPGP.decrypt(
      msg,
      decryptionKeys: [p3p.privateKey],
    );
    if (data.signingKeyIDs.length != 1) {
      return ParsedPayload(userInfo: null, events: []);
    }
    for (var useri in p3p.userInfoBox.getAll()) {
      if (useri.publicKey.fingerprint
          .endsWith(data.signingKeyIDs.first.toString())) {
        userInfo = useri;
      }
    }
    final body = data.literalData!.text;
    final jsonBody = json.decode(body) as List<dynamic>;
    for (var elm in jsonBody) {
      final evt = Event.fromJson(elm);
      if (userInfo == null && evt.eventType == EventType.introduce) {
        userInfo = UserInfo(
          dbPublicKey: ToOne(
            target: await PublicKey.create(evt.data["publickey"]),
          ),
        );
        userInfo.save(p3p);
      }
      ret.events.add(Event.fromJson(elm));
    }
    ret.userInfo = userInfo;
    if (ret.userInfo == null) {
      print("CRITICAL: ret.userInfo is null, returning but it will fail");
    }
    return ret;
  }

  Future<bool> process(UserInfo userInfo, P3p p3p) async {
    print("processing.. - ${userInfo.id} - ${userInfo.name} - $eventType");
    // JsonEncoder.withIndent('    ')
    //     .convert(toJson())
    //     .split("\n")
    //     .forEach((element) {
    //   print(element); // I hate the fact that flutter cuts the logs.
    // });
    switch (eventType) {
      case EventType.introduce:
        return await processIntroduce(p3p);
      case EventType.introduceRequest:
        return await processIntroduceRequest(p3p);
      case EventType.message:
        return await processMessage(p3p, userInfo);
      case EventType.fileRequest:
        return await processFileRequest(p3p, userInfo);
      case EventType.file:
        return await processFile(p3p, userInfo);
      case EventType.unimplemented || null:
        print("event: unimplemented");
        return false;
    }
  }

  Future<bool> processIntroduce(P3p p3p) async {
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
    UserInfo? useri = p3p.getUserInfo(publicKey.fingerprint);
    useri ??= UserInfo(
      dbPublicKey: ToOne(
        target: (await PublicKey.create(data['publickey']))!,
      ),
    )
      ..endpoint = [
        ...ReachableRelay.defaultEndpoints,
      ]
      ..save(p3p);
    useri.lastMessage = DateTime.now();
    final eList = <String>[];
    data["endpoint"].forEach((elm) {
      eList.add(elm.toString());
    });
    useri.endpoint.clear();
    useri.endpoint.addAll(Endpoint.fromStringList(eList));
    useri.name = data["username"];
    final elms = await useri.fileStore.getFileStoreElement(p3p);
    for (var elm in data["filestore"]) {
      bool fileExisted = false;
      for (var elmStored in elms) {
        if (elmStored.uuid != elm["uuid"]) continue;
        fileExisted = true;
        final modTime = DateTime.fromMicrosecondsSinceEpoch(elm["modifyTime"]);
        if (elmStored.modifyTime.isBefore(modTime)) {
          elmStored.path = elm["path"];
          elmStored.sha512sum = elm["sha512sum"];
          elmStored.sizeBytes = elm["sizeBytes"];
          elmStored.isDeleted = elm["isDeleted"];
          elmStored.modifyTime = modTime;
          elmStored.requestedLatestVersion = false;
          await elmStored.save(
            p3p,
            shouldIntroduce: false,
          );
        }
      }
      if (!fileExisted) {
        await useri.fileStore.putFileStoreElement(p3p,
            localFile: null,
            localFileSha512sum: elm["sha512sum"],
            sizeBytes: elm["sizeBytes"],
            fileInChatPath: elm["path"],
            uuid: elm["uuid"]);
      }
    }

    useri.save(p3p);
    return true;
  }

  Future<bool> processIntroduceRequest(P3p p3p) async {
    print("event: introduce.request");
    final publicKey = await pgp.OpenPGP.readPublicKey(data['publickey']);
    UserInfo? userInfo = p3p.getUserInfo(publicKey.fingerprint);
    final selfUser = await p3p.getSelfInfo();
    userInfo ??= UserInfo(
      dbPublicKey: ToOne(target: (await PublicKey.create(data['publickey']))!),
    );
    userInfo.endpoint.clear();
    userInfo.endpoint.addAll(
      Endpoint.fromStringList(data["endpoint"])
        ..addAll(ReachableRelay.defaultEndpoints),
    );

    userInfo.addEvent(
      p3p,
      Event(
        eventType: EventType.introduce,
        destinationPublicKey: ToOne(targetId: userInfo.publicKey.id),
      )..data = EventIntroduce(
          endpoint: selfUser.endpoint,
          fselm: await userInfo.fileStore.getFileStoreElement(p3p),
          publickey: p3p.privateKey.toPublic,
          username: selfUser.name ?? 'unknown username (ir)',
        ).toJson(),
    );
    return true;
  }

  Future<bool> processMessage(P3p p3p, UserInfo userInfo) async {
    print("event: processMessage");
    assert(eventType == EventType.message);
    await userInfo.addMessage(
      p3p,
      Message.fromEvent(this, true, userInfo.publicKey.fingerprint)!,
    );
    return true;
  }

  Future<bool> processFileRequest(
    P3p p3p,
    UserInfo userInfo,
  ) async {
    print("processFileRequest: ");
    assert(eventType == EventType.fileRequest);
    final freq = EventFileRequest.fromEvent(this);
    final file = p3p.fileStoreElementBox
        .query(FileStoreElement_.roomFingerprint
            .equals(userInfo.publicKey.fingerprint)
            .and(FileStoreElement_.uuid.equals(freq.uuid)))
        .build()
        .findFirst();
    if (file == null) return true; // we don't have that file
    final sendStart = freq.start ?? 0;
    final sendEnd = freq.end ?? await file.file.length();
    //min(file.sizeBytes, freq.end ?? (sendStart + 16 * 1024 * 1024));
    final bytes = await file.file.openRead(sendStart, sendEnd).first;

    userInfo.addEvent(
      p3p,
      Event(
        eventType: EventType.file,
        destinationPublicKey: ToOne(targetId: userInfo.publicKey.id),
      )..data = EventFile(
          bytes: Uint8List.fromList(bytes),
          end: sendEnd,
          start: sendStart,
          uuid: freq.uuid,
        ).toJson(),
    );
    return true;
  }

  Future<bool> processFile(P3p p3p, UserInfo userInfo) async {
    print("processFile: ");
    final incomingFile = EventFile.fromEvent(this);
    final file = p3p.fileStoreElementBox
        .query(FileStoreElement_.roomFingerprint
            .equals(userInfo.publicKey.fingerprint)
            .and(FileStoreElement_.uuid.equals(incomingFile.uuid)))
        .build()
        .findFirst();
    if (file == null) {
      print("processFile: file is null hm");
      return true;
    }
    if (incomingFile.start != 0 || incomingFile.end != file.sizeBytes) {
      print("processFile: doesn't start at 0 and doesn't end at sizeBytes");
      print(
          "if (${incomingFile.start} != 0 || ${incomingFile.end} != ${file.sizeBytes})");
    }
    file.file.writeAsBytes(incomingFile.bytes);
    file.sha512sum = FileStoreElement.calcSha512Sum(incomingFile.bytes);
    file.save(p3p);
    return true;
  }
}

enum EventType {
  unimplemented,
  introduce,
  introduceRequest,
  message,
  fileRequest,
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

  static EventFile fromEvent(Event event) {
    return EventFile(
      uuid: event.data["uuid"],
      start: event.data["start"],
      end: event.data["end"],
      bytes: base64.decode(event.data["bytes"]),
    );
  }
}
