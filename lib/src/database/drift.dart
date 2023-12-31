// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:p3p/p3p.dart' as ppp;
import 'package:p3p/src/chat.dart';
import 'package:p3p/src/database/abstract.dart';
import 'package:p3p/src/event.dart';
import 'package:path/path.dart' as p;

part 'drift.g.dart';

class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get typeIndex => integer()();
  TextColumn get body => text()();
  TextColumn get uuid => text()();
  BoolColumn get incoming => boolean()();
  TextColumn get roomFingerprint => text()();
  DateTimeColumn get dateReceived => dateTime()();
}

class Endpoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get protocol => text()();
  TextColumn get host => text()();
  TextColumn get extra => text()();
  IntColumn get reachTriesTotal => integer()();
  IntColumn get reachTriesSuccess => integer()();
}

class Errors extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get code => integer()();
  TextColumn get info => text()();
  DateTimeColumn get errorDate => dateTime()();
}

class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventTypeIndex => integer()();
  TextColumn get encryptPrivkeyArmor => text().nullable()();
  TextColumn get encryptPrivkeyPassword => text().nullable()();
  TextColumn get destinationPublicKeyFingerprint => text().nullable()();
  TextColumn get uuid => text()();
  BlobColumn get dataJson => blob()();
}

class PublicKeys extends Table {
  TextColumn get fingerprint => text()();
  TextColumn get publickey => text()();

  @override
  Set<Column> get primaryKey => {fingerprint};
}

class UserInfos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get publicKey => text()(); // references the fingerprint
  // UserInfoEndpoints
  TextColumn get name => text().nullable()();
  DateTimeColumn get lastMessage => dateTime()();
  DateTimeColumn get lastIntroduce => dateTime()();
  DateTimeColumn get lastEvent => dateTime()();
}

class UserInfoEndpoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userInfo => integer()();
  IntColumn get endpoint => integer()();
}

class FileStoreElements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get devicePath => text()();
  TextColumn get p3pPath => text()();
  TextColumn get roomFingerprint => text()();
  TextColumn get sha512sum => text()();
  IntColumn get sizeBytes => integer()();
  BoolColumn get shouldFetch => boolean()();
  BoolColumn get requestedLatestVersion => boolean()();
  DateTimeColumn get modifyTime => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(
  tables: [
    Messages,
    Endpoints,
    Errors,
    Events,
    PublicKeys,
    UserInfos,
    UserInfoEndpoints,
    FileStoreElements,
  ],
)
@Deprecated('Replaced with Isar.')
class DatabaseImplDrift extends _$DatabaseImplDrift implements Database {
  DatabaseImplDrift({required String dbFolder, required this.singularFileStore})
      : super(_openConnection(dbFolder)) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }
  @override
  final bool singularFileStore;
  final String singularFileStoreUuid = 'singular';
  @override
  int get schemaVersion => 1;

  @override
  Future<int> save<T>(T elm) async {
    // print('[driftdb] save($T elm):');
    return await _save(elm);
  }

  Future<int> _save<T>(T elm) async {
    switch (T) {
      case ppp.Message:
        if (elm is ppp.Message) {
          final typeIndex =
              MessageType.values.indexWhere((elm2) => elm2 == elm.type);
          final iq = MessagesCompanion.insert(
            id: elm.id == -1 ? const Value.absent() : Value(elm.id),
            typeIndex: typeIndex,
            body: elm.text,
            uuid: elm.uuid,
            incoming: elm.incoming,
            roomFingerprint: elm.roomFingerprint,
            dateReceived: elm.dateReceived,
          );
          if (elm.id == -1) {
            return await into(messages).insert(iq);
          } else {
            return await into(messages).insertOnConflictUpdate(iq);
          }
        }
      case ppp.Endpoint:
        if (elm is ppp.Endpoint) {
          return await into(endpoints).insertOnConflictUpdate(
            EndpointsCompanion.insert(
              id: elm.id == -1 ? const Value.absent() : Value(elm.id),
              protocol: elm.protocol,
              host: elm.host,
              extra: elm.extra,
              reachTriesTotal: elm.reachTriesTotal,
              reachTriesSuccess: elm.reachTriesSuccess,
            ),
          );
        }
      case ppp.P3pError:
        if (elm is ppp.P3pError) {
          return await into(errors).insertOnConflictUpdate(
            ErrorsCompanion.insert(
              id: elm.id == -1 ? const Value.absent() : Value(elm.id),
              code: elm.code,
              info: elm.info,
              errorDate: elm.errorDate,
            ),
          );
        }
      case ppp.Event:
        if (elm is ppp.Event) {
          if (elm.destinationPublicKey != null) {
            return await save(elm.destinationPublicKey!);
          }
          return await into(events).insertOnConflictUpdate(
            EventsCompanion.insert(
              id: elm.id == -1 ? const Value.absent() : Value(elm.id),
              eventTypeIndex:
                  EventType.values.indexWhere((elm2) => elm2 == elm.eventType),
              encryptPrivkeyArmor: Value(elm.encryptPrivkeyArmored),
              encryptPrivkeyPassword: Value(elm.encryptPrivkeyPassowrd),
              destinationPublicKeyFingerprint:
                  Value(elm.destinationPublicKey?.fingerprint),
              uuid: elm.uuid,
              dataJson: utf8.encode(json.encode(elm.data)) as Uint8List,
            ),
          );
        }
      case ppp.PublicKey:
        if (elm is ppp.PublicKey) {
          final pq = PublicKeysCompanion.insert(
            fingerprint: elm.fingerprint,
            publickey: elm.publickey,
          );
          final q = select(publicKeys)
            ..where((tbl) => tbl.fingerprint.equals(elm.fingerprint));
          final qresult = await q.getSingleOrNull();
          if (qresult == null) {
            return await into(publicKeys).insertOnConflictUpdate(pq);
          }
        }
      case ppp.UserInfo:
        if (elm is ppp.UserInfo) {
          if (await getPublicKey(fingerprint: elm.publicKey.fingerprint) ==
              null) {
            elm.publicKey.id = await save(elm.publicKey);
          }
          if (elm.endpoint.isNotEmpty) {
            final q = delete(userInfoEndpoints)
              ..where((tbl) => tbl.userInfo.equals(elm.id));
            await q.go();
            for (final endp in elm.endpoint) {
              await into(endpoints).insert(
                EndpointsCompanion.insert(
                  protocol: endp.protocol,
                  host: endp.host,
                  extra: endp.extra,
                  reachTriesTotal: endp.reachTriesTotal,
                  reachTriesSuccess: endp.reachTriesSuccess,
                ),
              );
            }
          }

          final uis = select(userInfos)
            ..where(
              (tbl) => tbl.publicKey.equals(elm.publicKey.fingerprint),
            );
          final ui = await uis.getSingleOrNull();

          final pi = UserInfosCompanion.insert(
            id: Value.ofNullable(ui?.id),
            publicKey: elm.publicKey.fingerprint,
            lastEvent: elm.lastEvent,
            lastIntroduce: elm.lastIntroduce,
            lastMessage: elm.lastMessage,
            name: Value(elm.name),
          );
          if (ui == null) {
            return await into(userInfos).insert(pi);
          } else {
            final q = update(userInfos);
            await q.replace(pi);
            return pi.id.value;
          }
        }
      case ppp.FileStoreElement:
        if (elm is ppp.FileStoreElement) {
          final q = select(fileStoreElements)
            ..where((tbl) => tbl.uuid.equals(elm.uuid))
            ..where(
              (tbl) => singularFileStore
                  ? tbl.roomFingerprint.equals(singularFileStoreUuid)
                  : tbl.roomFingerprint.equals(elm.roomFingerprint),
            )
            ..limit(1);
          final selm = await q.getSingleOrNull();
          final pi = FileStoreElementsCompanion.insert(
            id: Value.ofNullable(selm?.id),
            uuid: elm.uuid,
            devicePath: p.normalize(p.join('/', elm.localPath)),
            p3pPath: p.normalize(p.join('/', elm.path)),
            roomFingerprint:
                singularFileStore ? singularFileStoreUuid : elm.roomFingerprint,
            sizeBytes: elm.sizeBytes,
            shouldFetch: singularFileStore || elm.shouldFetch,
            requestedLatestVersion: elm.requestedLatestVersion,
            sha512sum: elm.sha512sum,
            deleted: Value(elm.isDeleted),
            modifyTime: elm.modifyTime,
          );

          if (selm == null) {
            return await into(fileStoreElements).insert(pi);
          } else {
            await update(fileStoreElements).replace(pi);
            return -1;
          }
        }
    }
    throw Exception('$T is not supported by save();');
  }

  @override
  Future<List<ppp.UserInfo>> getAllUserInfo() async {
    final uis = await (select(userInfos)
          ..orderBy(
            [
              (u) => OrderingTerm(
                    expression: u.lastMessage,
                    mode: OrderingMode.desc,
                  ),
            ],
          ))
        .get();
    final ret = <ppp.UserInfo>[];
    for (final element in uis) {
      ret.add(
        ppp.UserInfo(
          id: element.id,
          publicKey: (await getPublicKey(fingerprint: element.publicKey)),
          endpoint: await getUserInfoEndpointList(userInfoId: element.id),
        )
          ..name = element.name
          ..lastMessage = element.lastMessage
          ..lastIntroduce = element.lastIntroduce
          ..lastEvent = element.lastEvent,
      );
    }
    return ret;
  }

  @override
  Future<List<ppp.Event>> getEvents({
    required ppp.PublicKey? destinationPublicKey,
  }) async {
    if (destinationPublicKey == null) return [];
    // if (destinationPublicKey.id == -1) return [];
    final q = select(events)
      ..where(
        (tbl) => tbl.destinationPublicKeyFingerprint
            .equals(destinationPublicKey.fingerprint),
      )
      ..limit(16);
    final evts = await q.get();
    final ret = <ppp.Event>[];

    for (final elm in evts) {
      ret.add(
        ppp.Event(
          id: elm.id,
          eventType: EventType.values[elm.eventTypeIndex],
          encryptPrivkeyArmored: elm.encryptPrivkeyArmor,
          encryptPrivkeyPassowrd: elm.encryptPrivkeyPassword,
          destinationPublicKey: await getPublicKey(
            fingerprint: elm.destinationPublicKeyFingerprint,
          ),
          data: EventData.fromJson(
            json.decode(utf8.decode(elm.dataJson)) as Map<String, dynamic>,
            EventType.values[elm.eventTypeIndex],
          ),
        )..uuid = elm.uuid,
      );
    }
    return ret;
  }

  @override
  Future<ppp.FileStoreElement?> getFileStoreElement({
    required String? roomFingerprint,
    required String? uuid,
  }) async {
    final q = select(fileStoreElements);
    if (roomFingerprint != null && singularFileStore == false) {
      q.where(
        (tbl) => tbl.roomFingerprint.equals(
          singularFileStore ? singularFileStoreUuid : roomFingerprint,
        ),
      );
    }
    if (uuid != null) q.where((tbl) => tbl.uuid.equals(uuid));
    q.limit(1);
    final elm = await q.getSingleOrNull();
    if (elm == null) return null;
    return ppp.FileStoreElement(
      sha512sum: elm.sha512sum,
      path: elm.p3pPath,
      localPath: elm.devicePath,
      requestedLatestVersion: elm.requestedLatestVersion,
      roomFingerprint:
          singularFileStore ? singularFileStoreUuid : elm.roomFingerprint,
      shouldFetch: elm.shouldFetch,
      sizeBytes: elm.sizeBytes,
      isDeleted: elm.deleted,
    )
      ..uuid = elm.uuid
      ..id = elm.id
      ..modifyTime = elm.modifyTime;
  }

  @override
  Future<List<ppp.FileStoreElement>> getFileStoreElementList({
    required String? roomFingerprint,
    required bool? deleted,
  }) async {
    final q = select(fileStoreElements);
    if (roomFingerprint != null) {
      q.where(
        (tbl) => tbl.roomFingerprint.equals(
          singularFileStore ? singularFileStoreUuid : roomFingerprint,
        ),
      );
    }
    if (deleted != null) {
      q.where((tbl) => tbl.deleted.equals(deleted));
    }
    final ret = <ppp.FileStoreElement>[];
    final elms = await q.get();
    for (final elm in elms) {
      ret.add(
        ppp.FileStoreElement(
          localPath: elm.devicePath,
          path: elm.p3pPath,
          roomFingerprint:
              singularFileStore ? singularFileStoreUuid : elm.roomFingerprint,
          sha512sum: elm.sha512sum,
          sizeBytes: elm.sizeBytes,
          shouldFetch: elm.shouldFetch,
          requestedLatestVersion: elm.requestedLatestVersion,
          isDeleted: elm.deleted,
        )
          ..uuid = elm.uuid
          ..id = elm.id
          ..modifyTime = elm.modifyTime,
      );
    }
    return ret;
  }

  @override
  Future<ppp.Message?> getMessage({
    required String? uuid,
    required String? roomFingerprint,
  }) async {
    final q = select(messages);
    if (uuid != null) {
      q.where((tbl) => tbl.uuid.equals(uuid));
    }
    if (roomFingerprint != null) {
      q.where((tbl) => tbl.roomFingerprint.equals(roomFingerprint));
    }
    final elm = await q.getSingleOrNull();
    if (elm == null) return null;
    return ppp.Message(
      id: elm.id,
      type: MessageType.values[elm.typeIndex],
      text: elm.body,
      uuid: elm.uuid,
      incoming: elm.incoming,
      roomFingerprint: elm.roomFingerprint,
    )..dateReceived = elm.dateReceived;
  }

  @override
  Future<List<ppp.Message>> getMessageList({
    required String? roomFingerprint,
  }) async {
    final q = select(messages);
    if (roomFingerprint != null) {
      q.where((tbl) => tbl.roomFingerprint.equals(roomFingerprint));
    }
    final elms = await q.get();
    final toret = <ppp.Message>[];
    for (final elm in elms) {
      toret.add(
        ppp.Message(
          id: elm.id,
          type: MessageType.values[elm.typeIndex],
          text: elm.body,
          uuid: elm.uuid,
          incoming: elm.incoming,
          roomFingerprint: elm.roomFingerprint,
        )..dateReceived = elm.dateReceived,
      );
    }
    return toret;
  }

  @override
  Future<ppp.PublicKey?> getPublicKey({String? fingerprint}) async {
    if (fingerprint == null) return null;
    final q = select(publicKeys)
      ..where((tbl) => tbl.fingerprint.equals(fingerprint));
    // q.limit(1);
    final elm = await q.getSingleOrNull();
    if (elm == null) return null;
    return ppp.PublicKey(
      fingerprint: elm.fingerprint,
      publickey: elm.publickey,
    );
  }

  @override
  Future<ppp.UserInfo?> getUserInfo({
    ppp.PublicKey? publicKey,
    String? fingerprint,
  }) async {
    if (publicKey == null && fingerprint == null) return null;
    final q = select(userInfos);
    if (publicKey != null) {
      q.where((tbl) => tbl.publicKey.equals(publicKey!.fingerprint));
    }
    if (fingerprint != null) {
      publicKey = await getPublicKey(fingerprint: fingerprint);
      if (publicKey == null) return null;
      q.where((tbl) => tbl.publicKey.equals(publicKey!.fingerprint));
    }
    final ui = await q.getSingleOrNull();
    if (ui == null) return null;
    // UserInfoEndpoints

    return ppp.UserInfo(
      id: ui.id,
      publicKey: publicKey,
      endpoint: await getUserInfoEndpointList(userInfoId: ui.id),
    )
      ..name = ui.name
      ..lastMessage = ui.lastMessage
      ..lastIntroduce = ui.lastIntroduce
      ..lastEvent = ui.lastEvent;
  }

  @override
  Future<void> remove<T>(T elm) async {
    switch (T) {
      case ppp.Message:
        if (elm is ppp.Message) {
          await (delete(messages)..where((tbl) => tbl.id.equals(elm.id))).go();
          return;
        }
      case ppp.Endpoint:
        if (elm is ppp.Endpoint) {
          await (delete(endpoints)..where((tbl) => tbl.id.equals(elm.id))).go();
          return;
        }
      case ppp.P3pError:
        if (elm is ppp.P3pError) {
          await (delete(errors)..where((tbl) => tbl.id.equals(elm.id))).go();
          return;
        }
      case ppp.Event:
        if (elm is ppp.Event) {
          await (delete(events)..where((tbl) => tbl.id.equals(elm.id))).go();
          return;
        }
      case ppp.PublicKey:
        if (elm is ppp.PublicKey) {
          await (delete(publicKeys)
                ..where((tbl) => tbl.fingerprint.equals(elm.fingerprint)))
              .go();
          return;
        }
      case ppp.UserInfo:
        if (elm is ppp.UserInfo) {
          await (delete(userInfos)..where((tbl) => tbl.id.equals(elm.id))).go();
          return;
        }
      case ppp.FileStoreElement:
        if (elm is ppp.FileStoreElement) {
          await (delete(fileStoreElements)
                ..where((tbl) => tbl.id.equals(elm.id)))
              .go();
          return;
        }
    }
    throw UnimplementedError('$T is not supported by remove();');
  }

  Future<List<ppp.Endpoint>> getUserInfoEndpointList({
    required int userInfoId,
  }) async {
    final ret = <ppp.Endpoint>[];
    final cq = select(userInfoEndpoints)
      ..where((tbl) => tbl.userInfo.equals(userInfoId));
    final cqr = await cq.get();
    for (final intcq in cqr) {
      final elmq = select(endpoints)..where((tbl) => tbl.id.equals(intcq.id));
      final elm = await elmq.getSingle();
      ret.add(
        ppp.Endpoint(
          id: elm.id,
          protocol: elm.protocol,
          host: elm.host,
          extra: elm.extra,
          reachTriesTotal: elm.reachTriesTotal,
          reachTriesSuccess: elm.reachTriesSuccess,
        ),
      );
    }
    // We can no longer provide an easy way to getUserInfoEndpointList, since
    // we do not have p3p available here, but we shouldn't need to worry about
    // it because similar 'if' statememnt is at least in one more spots in this
    // code.
    // if (ret.isEmpty) return ReachableRelay.defaultEndpoints;
    return ret;
  }

  @override
  Future<ppp.Message?> getLastMessage() async {
    final q = select(messages)
      ..orderBy([
        (u) => OrderingTerm.desc(u.id),
      ])
      ..limit(1);
    final elm = await q.getSingleOrNull();
    if (elm == null) return null;
    return ppp.Message(
      id: elm.id,
      type: MessageType.values[elm.typeIndex],
      text: elm.body,
      uuid: elm.uuid,
      incoming: elm.incoming,
      roomFingerprint: elm.roomFingerprint,
    )..dateReceived = elm.dateReceived;
  }
}

LazyDatabase _openConnection(String dbFolder) {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final file = File(p.join(dbFolder, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
