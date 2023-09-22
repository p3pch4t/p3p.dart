import 'dart:async';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:logger/logger.dart' as logger;
import 'package:p3p/src/background.dart';
import 'package:p3p/src/chat.dart';
import 'package:p3p/src/database/abstract.dart';
import 'package:p3p/src/error.dart';
import 'package:p3p/src/event.dart';
import 'package:p3p/src/filestore.dart';
import 'package:p3p/src/publickey.dart';
import 'package:p3p/src/reachable/i2p.dart';
import 'package:p3p/src/reachable/local.dart';
import 'package:p3p/src/reachable/relay.dart';
import 'package:p3p/src/userinfo.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as io;

/// Main P3p object.
class P3p {
  /// You **SHOULD NOT** call it directly, unless you really know what you are
  /// doing. Instead you should use P3p.createSession function.
  P3p({
    required this.privateKey,
    required this.fileStorePath,
    required this.db,
  });

  /// Used internally to talk to the i2p network.
  ReachableI2p? reachableI2p;

  /// Used internally to talk to local peers. Used partially by ReachableI2p.
  ReachableLocal reachableLocal = ReachableLocal();

  /// User to talk to currently unreachable relays.
  ReachableRelay reachableRelay = ReachableRelay();

  /// Holds the unencrypted privatekey to be used for signing events
  final pgp.PrivateKey privateKey;

  /// Base path of where to store files
  final String fileStorePath;

  /// Database driver (example implementation: DatabaseImplDrift)
  final Database db;

  /// Use this instead of print()
  void print(dynamic element) {
    _logger.d(element);
  }

  /// Used internally to log stuff using p3p.print
  final logger.Logger _logger = logger.Logger(
    printer: logger.SimplePrinter(
      colors: false,
    ),
  );

  /// createSession loads the P3p object with properly initialized variables and
  /// background processes.
  /// storePath - where to store all files required for P3p to function?
  /// privateKey - armored, encrypted private key
  /// privateKeyPassword - password to decrypt privatekey
  /// db - Database driver (example implementation: DatabaseImplDrift)
  /// scheduleTasks = true - wether to call scheduleTasks()
  /// listen = true - wether to listen for incoming p2p connections
  static Future<P3p> createSession(
    String storePath,
    String privateKey,
    String privateKeyPassword,
    Database db, {
    bool scheduleTasks = true,
    bool listen = true,
    ReachableI2p? reachableI2p,
  }) async {
    final privkey = await (await pgp.OpenPGP.readPrivateKey(privateKey))
        .decrypt(privateKeyPassword);
    final p3p = P3p(
      privateKey: privkey,
      fileStorePath: p.join(storePath, 'files'),
      db: db,
    )
      ..print('p3p: using $storePath')
      ..reachableI2p = reachableI2p;

    try {
      if (listen) await p3p.listen();
    } catch (e) {
      p3p.print('listen set to true but failed: $e');
    }
    if (scheduleTasks) await p3p._scheduleTasks();
    return p3p;
  }

  /// Get UserInfo object about owner of this object
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
        ...ReachableRelay.getDefaultEndpoints(this),
      ],
    )..name = 'localuser [${privateKey.keyID}]';
    await db.save(useri);
    return useri;
  }

  /// Sends message to some user
  /// destination - UserInfo object of destination
  /// text - plaintext (markdown) text of the message
  /// type = MessageType.text - type of the message - used for displaying in ui
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
      ),
    );
    return null;
  }

  /// Fetch UserInfo? object by armored publickey
  /// armored - armored publickey
  Future<UserInfo?> getUserInfoByKey(String armored) async {
    final pubkey = await pgp.OpenPGP.readPublicKey(armored);
    return db.getUserInfo(
      publicKey: await db.getPublicKey(fingerprint: pubkey.fingerprint),
    );
  }

  /// alias for db.getAllUserInfo();
  @Deprecated('p3p.getUsers() should be replaced by p3p.db.getAllUserInfo()')
  Future<List<UserInfo>> getUsers() async {
    final uiList = await db.getAllUserInfo();
    return uiList;
  }

  /// listen for p2p events on 0.0.0.0:3893, called by default by createSession
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

  /// check wether of not scheduleTasks was already started, used by
  /// _scheduleTasks
  bool isScheduleTasksCalled = false;

  Future<void> _scheduleTasks() async {
    if (isScheduleTasksCalled) {
      print('scheduleTasks called more than once. this is unacceptable');
      return;
    }
    isScheduleTasksCalled = true;
    unawaited(scheduleTasks(this));
  }

  /// List<Function> of all callbacks that will be called on new messages.
  List<void Function(P3p p3p, Message msg, UserInfo user)> onMessageCallback =
      [];

  /// Used internally to call onMessageCallback
  Future<void> callOnMessage(Message msg) async {
    final ui = await msg.getSender(this);
    for (final fn in onMessageCallback) {
      fn(this, msg, ui);
    }
  }

  /// List<Function> onEventCallback
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
  /// Used internally to call onEventCallback
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
