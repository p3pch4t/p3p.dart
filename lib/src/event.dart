import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/relay.dart';
import 'package:uuid/uuid.dart';

class Event {
  Event({
    required this.eventType,
    required this.data,
    this.id = -1,
    this.encryptPrivkeyArmored,
    this.encryptPrivkeyPassowrd,
    this.destinationPublicKey,
  });
  int id = -1;
  EventType eventType;
  String? encryptPrivkeyArmored;
  String? encryptPrivkeyPassowrd;
  PublicKey? destinationPublicKey;
  Map<String, dynamic> data;
  String uuid = const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'type': switch (eventType) {
        EventType.introduce => 'introduce',
        EventType.introduceRequest => 'introduce.request',
        EventType.message => 'message',
        EventType.fileRequest => 'file.request',
        EventType.file => 'file',
        EventType.unimplemented => 'unimplemented',
      },
      'data': data,
      'uuid': uuid,
    };
  }

  static Event fromJson(Map<String, dynamic> json) {
    return Event(
      eventType: switch (json['type'] as String) {
        'introduce' => EventType.introduce,
        'introduce.request' => EventType.introduceRequest,
        'message' => EventType.message,
        'file.request' => EventType.fileRequest,
        'file' => EventType.file,
        _ => EventType.unimplemented,
      },
      data: json['data'] as Map<String, dynamic>,
    )..uuid = json['uuid'] as String;
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

      for (final evt in plainText) {
        if (evt is String) {
          final p = await parsePayload(payload, p3p);
          ui = p.userInfo;
          for (final evt in p.events) {
            await evt.process(ui!, p3p);
          }
          continue;
        }
        if (evt['type'] == 'introduce' || evt['type'] == 'introduce.request') {
          final evtp = Event.fromJson(evt as Map<String, dynamic>);
          if (evtp.eventType == EventType.introduce) {
            await evtp.processIntroduce(p3p);
          } else if (evtp.eventType == EventType.introduceRequest) {
            await evtp.processIntroduceRequest(p3p);
          } else {}
          continue;
        }
        return ui;
      }
    } catch (e) {
      // Okay, are not plaintext - this is more than fine.
      final parsed = await Event.parsePayload(payload, p3p);
      ui = parsed.userInfo;
      for (final element in parsed.events) {
        if (ui == null) {
          await tryProcess(p3p, payload);
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
      for (final element in src) {
        final evt = await Event.parsePayload(element.toString(), p3p);
        ret.events.addAll(evt.events);
        ret.userInfo = evt.userInfo;
        print('new event from:${ret.userInfo?.publicKey.fingerprint}');
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
    for (final useri in await p3p.db.getAllUserInfo()) {
      if (useri.publicKey.fingerprint
          .endsWith(data.signingKeyIDs.first.toString())) {
        userInfo = useri;
      }
    }
    final body = data.literalData!.text;
    final jsonBody = json.decode(body) as List<dynamic>;
    for (final elm in jsonBody) {
      final evt = Event.fromJson(elm as Map<String, dynamic>);
      if (userInfo == null && evt.eventType == EventType.introduce) {
        userInfo = UserInfo(
          publicKey:
              (await PublicKey.create(p3p, evt.data['publickey'] as String))!,
          endpoint: [...ReachableRelay.defaultEndpoints],
        );
        await userInfo.save(p3p);
      }
      ret.events.add(Event.fromJson(elm));
    }
    ret.userInfo = userInfo;
    if (ret.userInfo == null) {
      print('CRITICAL: ret.userInfo is null, returning but it will fail');
    }
    return ret;
  }

  Future<void> process(UserInfo userInfo, P3p p3p) async {
    print('processing: - ${userInfo.id} - ${userInfo.name} - $eventType');
    const JsonEncoder.withIndent('    ')
        .convert(toJson())
        .split('\n')
        .forEach((element) {
      print('$eventType: $element');
    });

    if (await p3p.callOnEvent(this)) {
      if (id != -1) {
        await p3p.db.remove(id);
      }
      return;
    }

    switch (eventType) {
      case EventType.introduce:
        await processIntroduce(p3p);
      case EventType.introduceRequest:
        await processIntroduceRequest(p3p);
      case EventType.message:
        await processMessage(p3p, userInfo);
      case EventType.fileRequest:
        await processFileRequest(p3p, userInfo);
      case EventType.file:
        await processFile(p3p, userInfo);
      case EventType.unimplemented:
        print('event: unimplemented');
    }
    if (id != 0) {
      await p3p.db.remove(this);
    }
  }

  Future<bool> processIntroduce(P3p p3p) async {
    print('event: introduce');
    if (data['publickey'] is! String ||
        data['endpoint'] is! List<dynamic> /* string actually.. */ ||
        data['username'] is! String ||
        data['filestore'] is! List<dynamic>) {
      print('invalid event, ignoring');
      print("publickey: ${data["publickey"].runtimeType}");
      print("endpoint: ${data["endpoint"].runtimeType}");
      print("username: ${data["username"].runtimeType}");
      print("filestore: ${data["filestore"].runtimeType}");
      return true;
    }
    final publicKey =
        await pgp.OpenPGP.readPublicKey(data['publickey'] as String);
    var useri = await p3p.db.getUserInfo(
      publicKey:
          (await p3p.db.getPublicKey(fingerprint: publicKey.fingerprint))!,
    );
    useri ??= UserInfo(
      publicKey: (await PublicKey.create(p3p, data['publickey'] as String))!,
      endpoint: [
        ...ReachableRelay.defaultEndpoints,
      ],
    );
    useri.lastMessage = DateTime.now();
    final eList = <String>[];
    data['endpoint'].forEach((elm) {
      eList.add(elm.toString());
    });
    useri.endpoint.clear();
    useri.endpoint.addAll(Endpoint.fromStringList(eList));
    useri.name = data['username'] as String?;
    final elms = await useri.fileStore.getFileStoreElement(p3p);
    print('processing filestore');
    for (final elm in data['filestore'] as List<dynamic>) {
      print('${elm['uuid']}');
      var fileExisted = false;
      for (final elmStored in elms) {
        if (elmStored.uuid != elm['uuid']) continue;
        // print('file existed = true');
        fileExisted = true;
        final modTime =
            DateTime.fromMicrosecondsSinceEpoch(elm['modifyTime'] as int);
        if (elmStored.modifyTime.isBefore(modTime)) {
          // print('actually updating');
          elmStored
            ..path = elm['path'] as String
            ..sha512sum = elm['sha512sum'] as String
            ..sizeBytes = elm['sizeBytes'] as int
            ..isDeleted = elm['isDeleted'] as bool
            ..modifyTime = modTime
            ..requestedLatestVersion = false;
          await p3p.db.save(elmStored);
        } else {
          // print('ignoring because');
          // print(' - remote:$modTime');
          // print(' - local :${elmStored.modifyTime}');
        }
      }
      if (!fileExisted) {
        print('file existed = false');

        await useri.fileStore.putFileStoreElement(
          p3p,
          localFile: null,
          localFileSha512sum: elm['sha512sum'] as String,
          sizeBytes: elm['sizeBytes'] as int,
          fileInChatPath: elm['path'] as String,
          uuid: elm['uuid'] as String,
        );
      }
    }
    print('processing filestore: done');

    await useri.save(p3p);
    return true;
  }

  Future<bool> processIntroduceRequest(P3p p3p) async {
    print('event: introduce.request');
    final publicKey =
        await pgp.OpenPGP.readPublicKey(data['publickey'] as String);
    var userInfo = await p3p.db.getUserInfo(
      publicKey:
          (await p3p.db.getPublicKey(fingerprint: publicKey.fingerprint))!,
    );
    final selfUser = await p3p.getSelfInfo();
    userInfo ??= UserInfo(
      publicKey: (await PublicKey.create(p3p, data['publickey'] as String))!,
      endpoint: Endpoint.fromStringList(data['endpoint'] as List<String>)
        ..addAll(ReachableRelay.defaultEndpoints),
    );

    await userInfo.addEvent(
      p3p,
      Event(
        eventType: EventType.introduce,
        destinationPublicKey: userInfo.publicKey,
        data: EventIntroduce(
          endpoint: selfUser.endpoint,
          fselm: await userInfo.fileStore.getFileStoreElement(p3p),
          publickey: p3p.privateKey.toPublic,
          username: selfUser.name ?? 'unknown username (ir)',
        ).toJson(),
      ),
    );
    return true;
  }

  Future<bool> processMessage(P3p p3p, UserInfo userInfo) async {
    print('event: processMessage');
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
    print('processFileRequest: ');
    assert(eventType == EventType.fileRequest);
    final freq = EventFileRequest.fromEvent(this);
    final file = await p3p.db.getFileStoreElement(
      roomFingerprint: userInfo.publicKey.fingerprint,
      uuid: freq.uuid,
    );
    if (file == null) return true; // we don't have that file
    final sendStart = freq.start ?? 0;
    final sendEnd = freq.end ?? await file.file.length();
    final bytes = await file.file.openRead(sendStart, sendEnd).first;

    await userInfo.addEvent(
      p3p,
      Event(
        eventType: EventType.file,
        destinationPublicKey: userInfo.publicKey,
        data: EventFile(
          bytes: Uint8List.fromList(bytes),
          end: sendEnd,
          start: sendStart,
          uuid: freq.uuid,
        ).toJson(),
      ),
    );
    return true;
  }

  Future<bool> processFile(P3p p3p, UserInfo userInfo) async {
    print('processFile: ');
    final incomingFile = EventFile.fromEvent(this);
    final file = await p3p.db.getFileStoreElement(
      roomFingerprint: userInfo.publicKey.fingerprint,
      uuid: incomingFile.uuid,
    );
    if (file == null) {
      print('processFile: file is null hm');
      return true;
    }
    if (incomingFile.start != 0 || incomingFile.end != file.sizeBytes) {
      print("processFile: doesn't start at 0 and doesn't end at sizeBytes");
      print(
        'if (${incomingFile.start} != 0 || ${incomingFile.end} != ${file.sizeBytes})',
      );
    }
    await file.file.writeAsBytes(incomingFile.bytes);
    file.sha512sum = FileStoreElement.calcSha512Sum(incomingFile.bytes);
    await file.save(p3p);
    return true;
  }

  Future<void> save(P3p p3p) async {
    await p3p.db.save(this);
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
    final endpoints = <String>[];
    for (final elm in endpoint) {
      endpoints.add(elm.toString());
    }
    return {
      'publickey': publickey.armor(),
      'endpoint': endpoints,
      'filestore': fselm,
      'username': username,
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
      'publickey': publickey.armor(),
      'endpoint': endpoint.toString(), // tostring
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
      'text': text,
      'type': switch (type) {
        MessageType.unimplemented => null,
        MessageType.text => 'text',
        MessageType.service => 'service',
        MessageType.hidden => 'hidden',
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
      'uuid': uuid,
      'start': start,
      'end': end,
    };
  }

  static EventFileRequest fromEvent(Event event) {
    return EventFileRequest(
      uuid: event.data['uuid'] as String,
      start: event.data['start'] as int?,
      end: event.data['end'] as int?,
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
      'uuid': uuid,
      'start': start,
      'end': end,
      'bytes': base64.encode(bytes),
    };
  }

  static EventFile fromEvent(Event event) {
    return EventFile(
      uuid: event.data['uuid'] as String,
      start: event.data['start'] as int,
      end: event.data['end'] as int,
      bytes: base64.decode(event.data['bytes'] as String),
    );
  }
}
