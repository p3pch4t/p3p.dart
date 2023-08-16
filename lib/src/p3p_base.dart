import 'dart:async';
import 'dart:io';

import 'package:p3p/objectbox.g.dart';
import 'package:p3p/src/background.dart';
import 'package:p3p/src/chat.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/error.dart';
import 'package:p3p/src/event.dart';
import 'package:p3p/src/filestore.dart';
import 'package:p3p/src/publickey.dart';
import 'package:p3p/src/reachable/local.dart';
import 'package:p3p/src/reachable/relay.dart';
import 'package:p3p/src/userinfo.dart';
import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:p3p/src/userinfossmdc.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:path/path.dart' as p;

bool storeIsOpen = false;

class P3p {
  P3p({
    required this.privateKey,
    required this.fileStorePath,
    required this.store,
  });

  final pgp.PrivateKey privateKey;
  final String fileStorePath;

  final Store store;

  late final userInfoBox = store.box<UserInfo>();
  late final userInfoSSMDCBox = store.box<UserInfoSSMDC>();
  late final messageBox = store.box<Message>();
  late final publicKeyBox = store.box<PublicKey>();
  late final endpointBox = store.box<Endpoint>();
  late final eventBox = store.box<Event>();
  late final fileStoreElementBox = store.box<FileStoreElement>();
  static Future<P3p> createSession(
    String storePath,
    String privateKey,
    String privateKeyPassword,
  ) async {
    print("p3p: using $storePath");
    final dbPath = Directory(p.join(storePath, 'dbv2'));
    if (!await dbPath.exists()) await dbPath.create(recursive: true);

    final privkey = await (await pgp.OpenPGP.readPrivateKey(privateKey))
        .decrypt(privateKeyPassword);
    if (storeIsOpen == false) {
      storeIsOpen = Store.isOpen(dbPath.absolute.path);
    }
    final newStore = storeIsOpen
        ? Store.attach(getObjectBoxModel(), dbPath.absolute.path)
        : openStore(
            directory: dbPath.absolute.path,
          );
    final p3p = P3p(
      privateKey: privkey,
      fileStorePath: p.join(storePath, 'files'),
      store: newStore,
    );
    if (!storeIsOpen) {
      await p3p.listen();
      p3p._scheduleTasks();
    }
    return p3p;
  }

  UserInfo? getUserInfo(String fingerprint) {
    return UserInfo.getUserInfo(this, fingerprint);
  }

  Future<UserInfo> getSelfInfo() async {
    UserInfo? useri = getUserInfo(privateKey.toPublic.fingerprint);
    useri ??= UserInfo(
      dbPublicKey: ToOne(
        target: (await PublicKey.create(privateKey.toPublic.armor()))!,
      ),
    )
      ..endpoint = [
        // ...ReachableLocal.defaultEndpoints,
        ...ReachableRelay.defaultEndpoints,
      ]
      ..name = "localuser [${privateKey.keyID}]";
    useri.save(this);
    return useri;
  }

  Future<P3pError?> sendMessage(UserInfo destination, String text,
      {MessageType type = MessageType.text}) async {
    final evt = Event(
      eventType: EventType.message,
      destinationPublicKey: ToOne(
        target: destination.publicKey,
      ),
    )..data = EventMessage(
        text: text,
        type: type,
      ).toJson();
    destination.addEvent(this, evt);
    final self = await getSelfInfo();
    self.addMessage(
      this,
      Message.fromEvent(evt, false, destination.publicKey.fingerprint)!,
    );
    return null;
  }

  Future<UserInfo?> getUserInfoByKey(String armored) async {
    final pubkey = await pgp.OpenPGP.readPublicKey(armored);
    return getUserInfo(pubkey.fingerprint);
  }

  Future<List<UserInfo>> getUsers() async {
    final uiList = userInfoBox.getAll();
    uiList.sort((ui, ui2) =>
        ui.lastMessage.microsecondsSinceEpoch -
        ui2.lastMessage.microsecondsSinceEpoch);
    return uiList;
  }

  Future<void> listen() async {
    try {
      final server = await io.serve(
        ReachableLocal.getListenRouter(this),
        '0.0.0.0',
        3893,
      );

      print('${server.address.address}:${server.port}');
    } catch (e) {
      print("failed to start server: $e");
    }
  }

  bool isScheduleTasksCalled = false;
  void _scheduleTasks() async {
    if (isScheduleTasksCalled) {
      print("scheduleTasks called more than once. this is unacceptable");
      return;
    }
    scheduleTasks(this);
  }

  List<void Function(P3p p3p, Message msg, UserInfo user)> onMessageCallback =
      [];
  void callOnMessage(Message msg) {
    final ui = getUserInfo(msg.roomFingerprint);
    if (ui == null) {
      print('callOnMessage: warn: user with fingerprint ${msg.roomFingerprint} '
          'doesn\'t exist. I\'ll not call any callbacks.');
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
  List<Future<bool> Function(P3p p3p, Event evt)> onEventCallback = [];
  Future<bool> callOnEvent(Event evt) async {
    bool toRet = false;
    for (final fn in onEventCallback) {
      if (await fn(this, evt)) toRet = true;
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
  void callOnFileStoreElement(FileStore fs, FileStoreElement fselm) {
    for (final fn in onFileStoreElementCallback) {
      fn.call(this, fs, fselm);
    }
  }
}
