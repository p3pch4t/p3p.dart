// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:isar/isar.dart';
import 'package:p3p/p3p.dart';
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
  static String fromEventType(EventType eventType) => switch (eventType) {
        EventType.introduce => 'introduce',
        EventType.introduceRequest => 'introduce.request',
        EventType.message => 'message',
        EventType.fileRequest => 'file.request',
        EventType.file => 'file',
        EventType.fileMetadata => 'file.metadata',
        EventType.unimplemented => 'unimplemented',
      };
  static EventType toEventType(String eventType) => switch (eventType) {
        'introduce' => EventType.introduce,
        'introduce.request' => EventType.introduceRequest,
        'message' => EventType.message,
        'file.request' => EventType.fileRequest,
        'file' => EventType.file,
        'file.metadata' => EventType.fileMetadata,
        _ => EventType.unimplemented,
      };
  int id = -1;
  EventType eventType;
  String? encryptPrivkeyArmored;
  String? encryptPrivkeyPassowrd;
  @ignore // make isar generator happy
  PublicKey? destinationPublicKey;
  // Map<String, dynamic> data;
  @ignore // make isar generator happy
  EventData? data;
  String uuid = const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'type': fromEventType(eventType),
      'data': data,
      'uuid': uuid,
    };
  }

  static Future<Event> fromJson(Map<String, dynamic> json) async {
    return Event(
      eventType: toEventType(json['type'] as String),
      data: EventData.fromJson(
        json['data'] as Map<String, dynamic>,
        toEventType(json['type'] as String),
      ),
    )..uuid = json['uuid'] as String;
  }

  static Future<UserInfo?> tryProcess(
    P3p p3p,
    String payload,
  ) async {
    // print('tryProcess: $payload');

    /// NOTE: we *do* want to process plaintext event: that is introduce
    /// We will use it send and optain publickey for encryption.
    /// NOTE 2: plaintext here may mean http*s* - but not PGP encrypted.
    /// NOTE 3: Okay, some extra comments are needed here because I've just
    /// revisited this place after a week and I have no idea what's happening

    // UserInfo (can be null) to return. We figure it out based on the signing
    // fingerprint. It is null when event wasn't signed/was plaintext.
    // It may be the case with 'introduce' and 'introduce.request' events
    UserInfo? ui;
    try {
      // Let's process a list of events,
      // It means that we have received plaintext array of events - that could
      // have been encrypted and signed.
      final jDecoded = json.decode(payload);
      if (jDecoded is String) return tryProcess(p3p, jDecoded);
      final plainList = json.decode(payload) as List<dynamic>;

      for (final evt in plainList) {
        // Do the normal processing.
        if (evt is String) {
          final p = await parsePayload(payload, p3p);
          ui = p.userInfo;
          for (final evt in p.events) {
            await evt.process(ui!, p3p);
          }
          continue;
        }
        if (evt is! Map<String, dynamic>) {
          p3p.print('####### event.dart - Event is NOT Map<String, dynamic> ( '
              'it is ${evt.runtimeType} )');
          return null;
        }
        // Or the events could be fully plaintext.
        final evtType = Event.toEventType(evt['type'] as String);
        if (evtType == EventType.introduce ||
            evtType == EventType.introduceRequest) {
          final evtp = await Event.fromJson(evt);
          if (evtp.eventType == EventType.introduce) {
            await evtp.processIntroduce(p3p);
          } else if (evtp.eventType == EventType.introduceRequest) {
            await evtp.processIntroduceRequest(p3p);
          }
          continue;
        }
        return null;
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
        p3p.print('new event from:${ret.userInfo?.publicKey.fingerprint}');
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
      final evt = await Event.fromJson(elm as Map<String, dynamic>);
      if (userInfo == null && evt.eventType == EventType.introduce) {
        userInfo = UserInfo(
          publicKey: await PublicKey.create(
            p3p,
            (evt.data! as EventIntroduce).publickey.armor(),
          ),
          endpoint: [...ReachableRelay.getDefaultEndpoints(p3p)],
        );
        userInfo.id = await p3p.db.save(userInfo);
      }
      ret.events.add(await Event.fromJson(elm));
    }
    ret.userInfo = userInfo;
    if (ret.userInfo == null) {
      p3p.print('CRITICAL: ret.userInfo is null, returning but it will fail');
    }
    return ret;
  }

  Future<void> process(UserInfo providedUserInfo, P3p p3p) async {
    var userInfo = providedUserInfo;
    final nui =
        await p3p.db.getUserInfo(fingerprint: userInfo.publicKey.fingerprint);
    if (nui != null) {
      userInfo = nui;
    }
    p3p.print('processing: - ${userInfo.id} - ${userInfo.name} - $eventType');
    const JsonEncoder.withIndent('    ')
        .convert(toJson())
        .split('\n')
        .forEach((element) {
      p3p.print('$eventType: $element');
    });
    p3p.print('processing...');
    if (eventType != EventType.introduce &&
        eventType != EventType.introduceRequest) {
      if (await p3p.callOnEvent(
        userInfo,
        this,
      )) {
        if (id != -1) {
          await p3p.db.remove(id);
        }
        return;
      }
    }
    p3p.print('still processing...');

    switch (eventType) {
      case EventType.introduce:
        await processIntroduce(p3p);
        await p3p.callOnEvent(userInfo, this);
      case EventType.introduceRequest:
        await processIntroduceRequest(p3p);
        await p3p.callOnEvent(userInfo, this);
      case EventType.message:
        await processMessage(p3p, userInfo);
      case EventType.fileRequest:
        await processFileRequest(p3p, userInfo);
      case EventType.fileMetadata:
        await processFileMetadata(p3p, userInfo);
      case EventType.file:
        await processFile(p3p, userInfo);
      case EventType.unimplemented:
        p3p.print('event: unimplemented');
    }
    if (id != 0) {
      await p3p.db.remove(this);
    }
  }

  Future<bool> processIntroduce(P3p p3p) async {
    p3p.print('event: introduce');
    final edata = data! as EventIntroduce;

    var useri = await p3p.db.getUserInfo(
      publicKey:
          await p3p.db.getPublicKey(fingerprint: edata.publickey.fingerprint),
    );
    useri ??= UserInfo(
      publicKey: await PublicKey.create(p3p, edata.publickey.armor()),
      endpoint: [
        ...ReachableRelay.getDefaultEndpoints(p3p),
      ],
    );
    if (edata.endpoint.isNotEmpty) {
      useri.endpoint = edata.endpoint;
    }
    useri.name = edata.username;

    useri.id = await p3p.db.save(useri);
    return true;
  }

  Future<bool> processIntroduceRequest(P3p p3p) async {
    p3p.print('event: introduce.request');

    final edata = data! as EventIntroduceRequest;
    var userInfo = await p3p.db.getUserInfo(
      publicKey:
          await p3p.db.getPublicKey(fingerprint: edata.publickey.fingerprint),
    );
    final selfUser = await p3p.getSelfInfo();
    userInfo ??= UserInfo(
      publicKey: await PublicKey.create(p3p, edata.publickey as String),
      endpoint: edata.endpoint..addAll(ReachableRelay.getDefaultEndpoints(p3p)),
    );

    await userInfo.addEvent(
      p3p,
      Event(
        eventType: EventType.introduce,
        destinationPublicKey: userInfo.publicKey,
        data: EventIntroduce(
          endpoint: selfUser.endpoint,
          publickey: p3p.privateKey.toPublic,
          username: selfUser.name ?? 'unknown username (ir)',
        ),
      ),
    );
    await userInfo.addEvent(
      p3p,
      Event(
        eventType: EventType.fileMetadata,
        data: EventFileMetadata(
          files: await userInfo.fileStore.getFileStoreElement(p3p),
        ),
      ),
    );
    return true;
  }

  Future<bool> processMessage(P3p p3p, UserInfo userInfo) async {
    p3p.print('event: processMessage');
    assert(
      eventType == EventType.message,
      'processMessage - eventType is not EventType.message',
    );
    await userInfo.addMessage(
      p3p,
      Message.fromEvent(this, userInfo.publicKey.fingerprint, incoming: true),
    );
    return true;
  }

  Future<bool> processFileRequest(
    P3p p3p,
    UserInfo userInfo,
  ) async {
    p3p.print('processFileRequest: ');
    assert(
      eventType == EventType.fileRequest,
      'processFileRequest - is not EventType.fileRequest',
    );
    final freq = data! as EventFileRequest;
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
        ),
      ),
    );
    return true;
  }

  Future<bool> processFile(P3p p3p, UserInfo userInfo) async {
    p3p.print('processFile: ');
    assert(
      eventType == EventType.file,
      'processFile - is not EventType.file',
    );
    final incomingFile = data! as EventFile; //EventFile.fromEvent(this);
    final file = await p3p.db.getFileStoreElement(
      roomFingerprint: userInfo.publicKey.fingerprint,
      uuid: incomingFile.uuid,
    );
    if (file == null) {
      p3p.print('processFile: file is null hm');
      return true;
    }
    if (incomingFile.start != 0 || incomingFile.end != file.sizeBytes) {
      p3p
        ..print("processFile: doesn't start at 0 and doesn't end at sizeBytes")
        ..print(
          // ignore: lines_longer_than_80_chars
          'if (${incomingFile.start} != 0 || ${incomingFile.end} != ${file.sizeBytes})',
        );
    }
    await file.file.writeAsBytes(incomingFile.bytes);
    file.sha512sum = FileStoreElement.calcSha512Sum(incomingFile.bytes);
    file.id = await p3p.db.save(file);
    return true;
  }

  Future<void> processFileMetadata(P3p p3p, UserInfo userInfo) async {
    final elms = await userInfo.fileStore.getFileStoreElement(p3p);
    p3p.print('processing fileMedatada');
    assert(
      eventType == EventType.fileMetadata,
      'processFileMetadata - is not EventType.fileMetadata',
    );
    final edata = data! as EventFileMetadata;
    for (final elm in edata.files) {
      p3p.print(elm.uuid);
      var fileExisted = false;
      for (final elmStored in elms) {
        if (elmStored.uuid != elm.uuid) continue;
        // print('file existed = true');
        fileExisted = true;
        if (elmStored.modifyTime.isBefore(elm.modifyTime)) {
          p3p.print('actually updating');
          elmStored
            ..path = elm.path
            ..sha512sum = elm.sha512sum
            ..sizeBytes = elm.sizeBytes
            ..isDeleted = elm.isDeleted
            ..modifyTime = elm.modifyTime
            ..requestedLatestVersion = false;
          elmStored.id = await p3p.db.save(elmStored);
        } else {
          p3p.print('ignoring because\n'
              ' - remote:${elm.modifyTime}'
              ' - local :${elmStored.modifyTime}');
        }
      }
      if (!fileExisted) {
        p3p.print('file existed = false');

        await userInfo.fileStore.putFileStoreElement(
          p3p,
          localFile: null,
          localFileSha512sum: elm.sha512sum,
          sizeBytes: elm.sizeBytes,
          fileInChatPath: elm.path,
          uuid: elm.uuid,
        );
      }
    }
    p3p.print('processing filestore: done');
  }
}

enum EventType {
  unimplemented,
  introduce,
  introduceRequest,
  message,
  fileRequest,
  file,
  fileMetadata,
}

class ParsedPayload {
  ParsedPayload({
    required this.userInfo,
    required this.events,
  });
  UserInfo? userInfo;
  List<Event> events;
}

abstract class EventData {
  static EventData? fromJson(
    Map<String, dynamic> data,
    EventType type,
  ) {
    return switch (type) {
      EventType.introduce => EventIntroduce.fromJson(data),
      EventType.introduceRequest => EventIntroduceRequest.fromJson(data),
      EventType.message => EventMessage.fromJson(data),
      EventType.fileRequest => EventFileRequest.fromJson(data),
      EventType.file => EventFile.fromJson(data),
      EventType.fileMetadata => EventFileMetadata.fromJson(data),
      EventType.unimplemented => null
    };
  }

  Map<String, dynamic> toJson();
}

class EventIntroduce implements EventData {
  EventIntroduce({
    required this.publickey,
    required this.endpoint,
    required this.username,
  });

  final pgp.PublicKey publickey;
  final List<Endpoint> endpoint;
  final String username;

  @override
  Map<String, dynamic> toJson() {
    final endpoints = <String>[];
    for (final elm in endpoint) {
      endpoints.add(elm.toString());
    }
    return {
      'publickey': publickey.armor(),
      'endpoint': endpoints,
      'username': username,
    };
  }

  static EventIntroduce fromJson(Map<String, dynamic> data) {
    final endps = <String>[];
    for (final elm in data['endpoint'] as List<dynamic>) {
      endps.add(elm.toString());
    }

    return EventIntroduce(
      publickey: pgp.PublicKey.fromArmored(data['publickey'] as String),
      endpoint: Endpoint.fromStringList(endps),
      username: data['username'] as String,
    );
  }
}

class EventFileMetadata implements EventData {
  EventFileMetadata({
    required this.files,
  });

  EventFileMetadata.fromJson(
    Map<String, dynamic> data, {
    this.files = const [],
  }) {
    for (final elm in data['files'] as List<dynamic>) {
      files.add(FileStoreElement.fromJson(elm as Map<String, dynamic>));
    }
  }

  final List<FileStoreElement> files;

  @override
  Map<String, dynamic> toJson() {
    return {
      'files': files,
    };
  }
}

class EventIntroduceRequest implements EventData {
  EventIntroduceRequest({
    required this.publickey,
    required this.endpoint,
  });

  final pgp.PublicKey publickey;
  final List<Endpoint> endpoint;

  @override
  Map<String, dynamic> toJson() {
    return {
      'publickey': publickey.armor(),
      'endpoint': Endpoint.toStringList(endpoint),
    };
  }

  static EventIntroduceRequest fromJson(
    Map<String, dynamic> data,
  ) {
    final endps = <String>[];
    for (final elm in data['endpoint'] as List<dynamic>) {
      endps.add(elm.toString());
    }

    return EventIntroduceRequest(
      publickey: pgp.PublicKey.fromArmored(data['publickey'] as String),
      endpoint: Endpoint.fromStringList(endps),
    );
  }
}

class EventMessage implements EventData {
  EventMessage({
    required this.text,
    required this.type,
  });

  EventMessage.fromJson(
    Map<String, dynamic> data,
  ) {
    text = data['text'] as String;
    type = switch (data['type'] as String) {
      'text' => MessageType.text,
      'service' => MessageType.service,
      'hidden' => MessageType.hidden,
      _ => MessageType.unimplemented,
    };
  }
  late String text;
  late MessageType type;

  @override
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': switch (type) {
        MessageType.unimplemented => null,
        MessageType.text => 'text',
        MessageType.service => 'service',
        MessageType.hidden => 'hidden',
      },
    };
  }
}

class EventFileRequest implements EventData {
  EventFileRequest({
    required this.uuid,
    this.start,
    this.end,
  });

  EventFileRequest.fromJson(
    Map<String, dynamic> data, {
    this.uuid = '',
  }) {
    uuid = data['uuid'] as String;
    start = data['start'] as int?;
    end = data['end'] as int?;
  }
  String uuid;
  int? start;
  int? end;
  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'start': start,
      'end': end,
    };
  }
}

class EventFile implements EventData {
  EventFile({
    required this.uuid,
    required this.start,
    required this.end,
    required this.bytes,
  });

  EventFile.fromJson(Map<String, dynamic> data) {
    uuid = data['uuid'] as String;
    start = data['start'] as int;
    end = data['end'] as int;
    bytes = base64.decode(data['bytes'] as String);
  }
  late String uuid;
  late int start;
  late int end;
  late Uint8List bytes;

  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'start': start,
      'end': end,
      'bytes': base64.encode(bytes),
    };
  }
}
