import 'dart:async';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:p3p/src/background.dart';
import 'package:p3p/src/chat.dart';
import 'package:p3p/src/database/abstract.dart';
import 'package:p3p/src/error.dart';
import 'package:p3p/src/event.dart';
import 'package:p3p/src/filestore.dart';
import 'package:p3p/src/publickey.dart';
import 'package:p3p/src/reachable/local.dart';
import 'package:p3p/src/reachable/relay.dart';
import 'package:p3p/src/userinfo.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as io;

bool storeIsOpen = false;

class P3p {
  P3p({
    required this.privateKey,
    required this.fileStorePath,
    required this.db,
  });

  final pgp.PrivateKey privateKey;
  final String fileStorePath;
  final Database db;

  static Future<P3p> createSession(
    String storePath,
    String privateKey,
    String privateKeyPassword,
    Database db, {
    bool scheduleTasks = true,
    bool listen = true,
  }) async {
    print('p3p: using $storePath');

    final privkey = await (await pgp.OpenPGP.readPrivateKey(privateKey))
        .decrypt(privateKeyPassword);
    final p3p = P3p(
      privateKey: privkey,
      fileStorePath: p.join(storePath, 'files'),
      db: db,
    );
    try {
      if (listen) await p3p.listen();
    } catch (e) {
      print('listen set to true but failed: $e');
    }
    if (scheduleTasks) await p3p._scheduleTasks();
    return p3p;
  }

  Future<UserInfo> getSelfInfo() async {
    final pubKey = await db.getPublicKey(fingerprint: privateKey.fingerprint);

    var useri = await db.getUserInfo(
      publicKey: pubKey,
    );
    if (useri != null) return useri;
    useri = UserInfo(
      publicKey: (await PublicKey.create(this, privateKey.toPublic.armor()))!,
      endpoint: [
        // ...ReachableLocal.defaultEndpoints,
        ...ReachableRelay.defaultEndpoints,
      ],
    )..name = 'localuser [${privateKey.keyID}]';
    await db.save(useri);
    return useri;
  }

  Future<P3pError?> sendMessage(
    UserInfo destination,
    String text, {
    MessageType type = MessageType.text,
  }) async {
    final evt = Event(
      eventType: EventType.message,
      destinationPublicKey: destination.publicKey,
      data: EventMessage(
        text: text,
        type: type,
      ),
    );
    await destination.addEvent(this, evt);
    final self = await getSelfInfo();
    await self.addMessage(
      this,
      Message.fromEvent(
        evt,
        destination.publicKey.fingerprint,
        incoming: false,
      )!,
    );
    return null;
  }

  Future<UserInfo?> getUserInfoByKey(String armored) async {
    final pubkey = await pgp.OpenPGP.readPublicKey(armored);
    return await db.getUserInfo(
      publicKey: await db.getPublicKey(fingerprint: pubkey.fingerprint),
    );
  }

  Future<List<UserInfo>> getUsers() async {
    final uiList = await db.getAllUserInfo();
    return uiList;
  }

  Future<void> listen() async {
    try {
      final server = await io.serve(
        ReachableLocal.getListenRouter(this).call,
        '0.0.0.0',
        3893,
      );
      print('${server.address.address}:${server.port}');
    } catch (e) {
      print('failed to start server: $e');
    }
  }

  bool isScheduleTasksCalled = false;
  Future<void> _scheduleTasks() async {
    if (isScheduleTasksCalled) {
      print('scheduleTasks called more than once. this is unacceptable');
      return;
    }
    unawaited(scheduleTasks(this));
  }

  List<void Function(P3p p3p, Message msg, UserInfo user)> onMessageCallback =
      [];
  Future<void> callOnMessage(Message msg) async {
    final ui = await msg.getSender(this);
    if (ui == null) {
      print('callOnMessage: warn: user with fingerprint ${msg.roomFingerprint} '
          "doesn't exist. I'll not call any callbacks.");
      return;
    }
    for (final fn in onMessageCallback) {
      fn(this, msg, ui);
    }
  }

  /// true - event will be deleted afterwards, while being marked
  /// as executed
  /// false - continue normal exacution
  /// in a situation where we have many callbacks present every
  /// sigle one will be called, no matter the boolean result of
  /// previous one.
  /// This function **is** blocking, entire loop will not continue
  /// execution untill you resolve all Futures
  /// However if new event arrives it will execute normally.
  /// Avoid long blocking of events to not render your peer
  /// unresponsive or to not have out of sync events in database.
  List<Future<bool> Function(P3p p3p, Event evt, UserInfo ui)> onEventCallback =
      [];

  /// see: onEventCallback
  Future<bool> callOnEvent(UserInfo userInfo, Event evt) async {
    var toRet = false;
    for (final fn in onEventCallback) {
      if (await fn(this, evt, userInfo)) toRet = true;
    }
    return toRet;
  }

  /// onFileStoreElementCallback functions are being called once a
  /// FileStoreElement().save() function is called,
  /// that is
  ///  - when user edits the file
  ///  - when file is updated by event
  ///  - at some other points too
  /// If you want to block file edit or intercept it you should be
  /// using onEventCallback (in most cases)
  List<void Function(P3p p3p, FileStore fs, FileStoreElement fselm)>
      onFileStoreElementCallback = [];

  /// see: onFileStoreElementCallback
  void callOnFileStoreElement(FileStore fs, FileStoreElement fselm) {
    for (final fn in onFileStoreElementCallback) {
      fn.call(this, fs, fselm);
    }
  }
}
