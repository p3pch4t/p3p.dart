// ignore_for_file: public_member_api_docs, overridden_fields, cascade_invocations

import 'dart:convert';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:p3p/p3p.dart' as ppp;
import 'package:p3p/src/chat.dart';
import 'package:p3p/src/database/abstract.dart';
import 'package:p3p/src/event.dart';
import 'package:p3p/src/filestore.dart';
import 'package:p3p/src/publickey.dart';
part 'isar.g.dart';

@collection
class DBMessage extends ppp.Message {
  DBMessage({
    required this.id,
    required super.text,
    required super.uuid,
    required super.incoming,
    required super.roomFingerprint,
    required this.type,
  }) : super(type: type);

  @override
  Id id = Isar.autoIncrement;

  @override
  @enumerated
  ppp.MessageType type;
}

@collection
class DBEndpoint extends ppp.Endpoint {
  DBEndpoint({
    required this.id,
    required super.protocol,
    required super.host,
    required super.extra,
  });
  @override
  Id id = Isar.autoIncrement;
}

@collection
class DBP3pError extends ppp.P3pError {
  DBP3pError({
    required this.id,
    required super.code,
    required super.info,
  });
  @override
  Id id = Isar.autoIncrement;
}

@collection
class DBEvent extends ppp.Event {
  DBEvent({
    required this.id,
    required this.eventType,
    required this.publicKeyId,
    ppp.PublicKey? destPublicKey,
    super.data,
  }) : super(eventType: eventType) {
    super.destinationPublicKey = destPublicKey;
    if (super.data == null) return;
    rawData = jsonEncode(super.data!.toJson());
  }
  @override
  Id id = Isar.autoIncrement;

  @override
  @enumerated
  ppp.EventType eventType;

  int? publicKeyId;

  @ignore
  @override
  ppp.EventData? get data => EventData.fromJson(
        jsonDecode(rawData) as Map<String, dynamic>,
        eventType,
      );

  @override
  set data(ppp.EventData? data) {
    if (data == null) return;
    rawData = jsonEncode(data.toJson());
  }

  late String rawData;
}

@collection
class DBPublicKey extends ppp.PublicKey {
  DBPublicKey({
    required this.id,
    required this.fingerprint,
    required super.publickey,
  }) : super(fingerprint: fingerprint);
  @override
  Id id = -1;

  @override
  @Index(unique: true, replace: true)
  String fingerprint;
}

@collection
class DBUserInfo extends ppp.UserInfo {
  DBUserInfo({
    required this.id,
    required this.publicKeyId,
    required this.rawEndpointsId,
    super.endpoint = const [],
    super.publicKey,
  }) {
    endpoint = super.endpoint;
  }
  @override
  Id id = Isar.autoIncrement;

  int publicKeyId;

  List<int> rawEndpointsId;
}

@collection
class DBFileStoreElement extends ppp.FileStoreElement {
  DBFileStoreElement({
    required this.id,
    required super.sha512sum,
    required super.sizeBytes,
    required super.localPath,
    required super.roomFingerprint,
    required super.path,
    required this.uuid,
  }) {
    super.uuid = uuid;
  }

  @override
  Id id = Isar.autoIncrement;

  @override
  @Index(unique: true, replace: true)
  final String uuid;
}

class DatabaseImplIsar implements Database {
  late Isar _isar;
  // cat lib/src/database/isar.g.dart| grep DB | grep Schema | awk '{print $2}'
  static Future<DatabaseImplIsar> open({required String dbPath}) async {
    final dir = Directory(dbPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final isar = await Isar.open(
      [
        DBMessageSchema,
        DBEndpointSchema,
        DBP3pErrorSchema,
        DBEventSchema,
        DBPublicKeySchema,
        DBUserInfoSchema,
        DBFileStoreElementSchema,
      ],
      directory: dbPath,
    );
    final db = DatabaseImplIsar().._isar = isar;
    return db;
  }

  @override
  Future<List<DBUserInfo>> getAllUserInfo() async {
    final users = await _isar.collection<DBUserInfo>().where().findAll();
    for (var i = 0; i < users.length; i++) {
      final pk = _isar
          .collection<DBPublicKey>()
          .filter()
          .idEqualTo(users[i].publicKeyId)
          .findFirstSync();
      if (pk == null) {
        _isar.writeTxnSync(
          () => _isar.collection<DBUserInfo>().deleteSync(users[i].id),
        );
        continue;
      }
      users[i].publicKey = pk;
      for (final endp in users[i].endpoint) {
        users[i].endpoint.add(
              _isar
                  .collection<DBEndpoint>()
                  .filter()
                  .idEqualTo(endp.id)
                  .findFirstSync()!,
            );
      }
    }
    return users;
  }

  @override
  Future<List<DBEvent>> getEvents({required PublicKey destinationPublicKey}) {
    return _isar
        .collection<DBEvent>()
        .filter()
        .publicKeyIdEqualTo(destinationPublicKey.id)
        .findAll();
  }

  @override
  Future<FileStoreElement?> getFileStoreElement({
    required String? roomFingerprint,
    required String? uuid,
  }) {
    assert(
      roomFingerprint != null || uuid != null,
      'roomFingerprint or uuid needs to be provided to getFileStoreElement',
    );

    final q1 = _isar.collection<DBFileStoreElement>().filter();
    if (roomFingerprint != null && uuid != null) {
      return q1
          .roomFingerprintEqualTo(roomFingerprint)
          .and()
          .uuidEqualTo(uuid)
          .findFirst();
    } else if (roomFingerprint != null) {
      return q1.roomFingerprintEqualTo(roomFingerprint).findFirst();
    } else if (uuid != null) {
      return q1.uuidEqualTo(uuid).findFirst();
    } else {
      throw UnimplementedError(
        "Can't find element if no roomFingerprint or uuid is provided.",
      );
    }
  }

  @override
  Future<List<DBFileStoreElement>> getFileStoreElementList({
    required String roomFingerprint,
    required bool deleted,
  }) {
    return _isar
        .collection<DBFileStoreElement>()
        .filter()
        .roomFingerprintEqualTo(roomFingerprint)
        .isDeletedEqualTo(deleted)
        .findAll();
  }

  @override
  Future<DBMessage?> getLastMessage() {
    return _isar.collection<DBMessage>().where(sort: Sort.desc).findFirst();
  }

  @override
  Future<DBMessage?> getMessage({
    required String uuid,
    required String roomFingerprint,
  }) {
    return _isar
        .collection<DBMessage>()
        .filter()
        .uuidEqualTo(uuid)
        .roomFingerprintEndsWith(roomFingerprint)
        .findFirst();
  }

  @override
  Future<List<DBMessage>> getMessageList({required String roomFingerprint}) {
    return _isar
        .collection<DBMessage>()
        .filter()
        .roomFingerprintEqualTo(roomFingerprint)
        .findAll();
  }

  @override
  Future<DBPublicKey?> getPublicKey({required String fingerprint}) {
    return _isar
        .collection<DBPublicKey>()
        .filter()
        .fingerprintEqualTo(fingerprint)
        .findFirst();
  }

  @override
  Future<DBUserInfo?> getUserInfo({
    PublicKey? publicKey,
    String? fingerprint,
  }) async {
    final pubKey = _isar.collection<DBPublicKey>().filter();
    if (publicKey != null) {
      final pk =
          pubKey.fingerprintEqualTo(publicKey.fingerprint).findFirstSync();
      if (pk?.id == null) return null;
      final ui = _isar
          .collection<DBUserInfo>()
          .filter()
          .publicKeyIdEqualTo(pk!.id)
          .findFirstSync();
      if (ui == null) return null;
      ui.publicKey = _isar.collection<DBPublicKey>().getSync(ui.publicKeyId)!;
      ui.endpoint = _isar
          .collection<DBEndpoint>()
          .getAllSync(ui.rawEndpointsId)
          .map((e) => e!)
          .toList();
      return ui;
    } else if (fingerprint != null) {
      final pk = pubKey.fingerprintEqualTo(fingerprint).findFirstSync();
      if (pk?.id == null) return null;
      final ui = _isar
          .collection<DBUserInfo>()
          .filter()
          .publicKeyIdEqualTo(pk!.id)
          .findFirstSync();
      if (ui == null) return null;
      ui.publicKey = _isar.collection<DBPublicKey>().getSync(ui.publicKeyId)!;
      ui.endpoint = _isar
          .collection<DBEndpoint>()
          .getAllSync(ui.rawEndpointsId)
          .map((e) => e!)
          .toList();
      return ui;
    } else {
      throw UnimplementedError(
        'either publicKey or fingerprint needs to be provided.',
      );
    }
  }

  @override
  Future<void> remove<T>(T elm) {
    switch (T) {
      case ppp.Message:
        _isar.collection<DBMessage>().delete((elm as ppp.Message).id);
      case ppp.Endpoint:
        _isar.collection<DBEndpoint>().delete((elm as ppp.Endpoint).id);
      case ppp.P3pError:
        _isar.collection<DBP3pError>().delete((elm as ppp.P3pError).id);
      case ppp.Event:
        _isar.collection<DBEvent>().delete((elm as ppp.Event).id);
      case ppp.PublicKey:
        _isar
            .collection<DBPublicKey>()
            .filter()
            .fingerprintEqualTo((elm as ppp.PublicKey).fingerprint)
            .deleteAll();
      case ppp.UserInfo:
        _isar.collection<DBUserInfo>().delete((elm as ppp.UserInfo).id);
      case ppp.FileStoreElement:
        _isar
            .collection<DBFileStoreElement>()
            .delete((elm as DBFileStoreElement).id);
    }
    throw UnimplementedError('$T is not supported by remove();');
  }

  @override
  Future<int> save<T>(T elm) async {
    print('[isar] save($elm)');
    return await _save(elm);
  }

  Future<int> _save<T>(T elm) async {
    await _isar.writeTxn(() async {
      switch (T) {
        case ppp.Message:
          if (elm is ppp.Message) {
            return await _isar.collection<DBMessage>().put(
                  DBMessage(
                    id: elm.id == -1 ? Isar.autoIncrement : elm.id,
                    text: elm.text,
                    uuid: elm.uuid,
                    incoming: elm.incoming,
                    roomFingerprint: elm.roomFingerprint,
                    type: elm.type,
                  )..dateReceived = elm.dateReceived,
                );
          }

        case ppp.Endpoint:
          if (elm is ppp.Endpoint) {
            return await _isar.collection<DBEndpoint>().put(
                  DBEndpoint(
                    id: elm.id == -1 ? Isar.autoIncrement : elm.id,
                    protocol: elm.protocol,
                    host: elm.host,
                    extra: elm.extra,
                  )
                    ..reachTriesTotal = elm.reachTriesTotal
                    ..reachTriesSuccess = elm.reachTriesSuccess,
                );
          }
        case ppp.P3pError:
          if (elm is ppp.P3pError) {
            return await _isar.collection<DBP3pError>().put(
                  DBP3pError(
                    id: elm.id == -1 ? Isar.autoIncrement : elm.id,
                    code: elm.code,
                    info: elm.info,
                  )..errorDate = elm.errorDate,
                );
          }
        case ppp.Event:
          if (elm is ppp.Event) {
            return await _isar.collection<DBEvent>().put(
                  DBEvent(
                    id: elm.id == -1 ? Isar.autoIncrement : elm.id,
                    eventType: elm.eventType,
                    data: elm.data,
                    publicKeyId: elm.destinationPublicKey?.id,
                    destPublicKey: elm.destinationPublicKey?.fingerprint == null
                        ? null
                        : await getPublicKey(
                            fingerprint: elm.destinationPublicKey!.fingerprint,
                          ),
                  )
                    ..encryptPrivkeyArmored = elm.encryptPrivkeyArmored
                    ..encryptPrivkeyPassowrd = elm.encryptPrivkeyPassowrd
                    ..destinationPublicKey = elm.destinationPublicKey
                    ..uuid = elm.uuid,
                );
          }
        case ppp.PublicKey:
          if (elm is ppp.PublicKey) {
            return await _isar.collection<DBPublicKey>().put(
                  DBPublicKey(
                    id: elm.id == -1 ? Isar.autoIncrement : elm.id,
                    fingerprint: elm.fingerprint,
                    publickey: elm.publickey,
                  ),
                );
          }
        case ppp.UserInfo:
          if (elm is ppp.UserInfo) {
            var pk = await _isar
                .collection<DBPublicKey>()
                .filter()
                .fingerprintEqualTo(elm.publicKey.fingerprint)
                .findFirst();

            pk ??= DBPublicKey(
              id: elm.publicKey.id == -1
                  ? Isar.autoIncrement
                  : elm.publicKey.id,
              fingerprint: elm.publicKey.fingerprint,
              publickey: elm.publicKey.publickey,
            );
            pk.id = await _isar.collection<DBPublicKey>().put(pk);

            final endpsRaw = elm.endpoint
                .map(
                  (e) => DBEndpoint(
                    id: e.id == -1 ? Isar.autoIncrement : e.id,
                    protocol: e.protocol,
                    host: e.host,
                    extra: e.extra,
                  )
                    ..reachTriesTotal = e.reachTriesTotal
                    ..reachTriesSuccess = e.reachTriesSuccess,
                )
                .toList();
            final endps = await _isar.collection<DBEndpoint>().putAll(
                  endpsRaw,
                );
            return await _isar.collection<DBUserInfo>().put(
                  DBUserInfo(
                    id: elm.id == -1 ? Isar.autoIncrement : elm.id,
                    publicKey: pk,
                    publicKeyId: pk.id,
                    rawEndpointsId: endps,
                    endpoint: endpsRaw,
                  )
                    ..publicKey = pk
                    ..endpoint = endpsRaw
                    ..lastEvent = elm.lastEvent
                    ..lastIntroduce = elm.lastIntroduce
                    ..lastMessage = elm.lastMessage
                    ..name = elm.name,
                );
          }
        case ppp.FileStoreElement:
          if (elm is ppp.FileStoreElement) {
            return await _isar.collection<DBFileStoreElement>().put(
                  DBFileStoreElement(
                    id: elm.id == -1 ? Isar.autoIncrement : elm.id,
                    sha512sum: elm.sha512sum,
                    sizeBytes: elm.sizeBytes,
                    localPath: elm.localPath,
                    path: elm.path,
                    roomFingerprint: elm.roomFingerprint,
                    uuid: elm.uuid,
                  )
                    ..shouldFetch = elm.shouldFetch
                    ..requestedLatestVersion = elm.requestedLatestVersion
                    ..isDeleted = elm.isDeleted
                    ..modifyTime = elm.modifyTime,
                );
          }
        default:
          throw Exception('$T is not supported by save();');
      }
    });
    return -1;
  }

  @override
  bool get singularFileStore => false;
}
