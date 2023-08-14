import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:p3p/objectbox.g.dart';
import 'package:p3p/src/chat.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/error.dart';
import 'package:p3p/src/event.dart';
import 'package:p3p/src/filestore.dart';
import 'package:p3p/src/publickey.dart';
import 'package:p3p/src/reachable/relay.dart';
import 'package:p3p/src/userinfo.dart';
import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:p3p/src/userinfossmdc.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:path/path.dart' as p;

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

    final privkey = await (await pgp.OpenPGP.readPrivateKey(privateKey))
        .decrypt(privateKeyPassword);

    final dbPath = Directory(p.join(storePath, 'dbv2'));
    if (!await dbPath.exists()) await dbPath.create(recursive: true);
    final p3p = P3p(
      privateKey: privkey,
      fileStorePath: p.join(storePath, 'files'),
      store: openStore(
        directory: dbPath.absolute.path,
      ),
    );
    await p3p.listen();
    p3p.scheduleTasks();
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
    var router = Router();
    router.post("/", (Request request) async {
      final body = await request.readAsString();
      final userI = await Event.tryProcess(this, body);
      if (userI == null) {
        return Response(
          404,
          body: JsonEncoder.withIndent('    ').convert(
            [
              (Event(
                eventType: EventType.introduceRequest,
                destinationPublicKey: ToOne(),
              )..data = EventIntroduceRequest(
                      endpoint: (await getSelfInfo()).endpoint,
                      publickey: privateKey.toPublic,
                    ).toJson())
                  .toJson(),
            ],
          ),
        );
      }
      return Response(
        200,
        body: await userI.relayEventsString(this),
      );
    });
    try {
      final server = await io.serve(router, '0.0.0.0', 3893);

      print('${server.address.address}:${server.port}');
    } catch (e) {
      print("failed to start server: $e");
    }
  }

  bool isScheduleTasksCalled = false;
  void scheduleTasks() async {
    if (isScheduleTasksCalled) {
      print("scheduleTasks called more than once. this is unacceptable");
      return;
    }
    isScheduleTasksCalled = true;
    Timer.periodic(
      Duration(seconds: 5),
      (Timer t) async {
        UserInfo si = await pingRelay();
        si.save(this);
        si.relayEvents(this, si.publicKey);
        await processTasks(si);
      },
    );
  }

  Future<void> processTasks(UserInfo si) async {
    for (UserInfo ui in userInfoBox.getAll()) {
      print("schedTask: ${ui.id} - ${si.id}");
      if (ui.id == si.id) continue;
      // begin file request
      final fs = await ui.fileStore.getFileStoreElement(this);
      for (var felm in fs) {
        if (felm.isDeleted == false &&
            await felm.file.length() != felm.sizeBytes &&
            felm.shouldFetch == true &&
            felm.requestedLatestVersion == false) {
          felm.requestedLatestVersion = true;
          await felm.save(this);
          ui.addEvent(
            this,
            Event(
              eventType: EventType.fileRequest,
              destinationPublicKey: ToOne(targetId: ui.publicKey.id),
            )..data = EventFileRequest(
                uuid: felm.uuid,
              ).toJson(),
          );
          ui.save(this);
        }
      }
      // end file request
      final diff = DateTime.now().difference(ui.lastIntroduce).inMinutes;
      print('p3p: ${ui.publicKey.fingerprint} : scheduleTasks diff = $diff');
      if (diff > 60) {
        ui.addEvent(
          this,
          Event(
            eventType: EventType.introduce,
            destinationPublicKey: ToOne(target: ui.publicKey),
          )..data = EventIntroduce(
              endpoint: si.endpoint,
              fselm: await ui.fileStore.getFileStoreElement(this),
              publickey: privateKey.toPublic,
              username: si.name ?? "unknown name [${DateTime.now()}]",
            ).toJson(),
        );
        ui.lastIntroduce = DateTime.now();
      } else {
        ui.relayEvents(this, ui.publicKey);
      }
      ui.save(this);
    }
  }

  Future<UserInfo> pingRelay() async {
    final si = await getSelfInfo();
    if (DateTime.now().difference(si.lastEvent).inSeconds < 15) {
      si.addEvent(
        this,
        Event(
          eventType: EventType.unimplemented,
          destinationPublicKey: ToOne(targetId: si.publicKey.id),
        ),
      );
    }
    return si;
  }

  void callOnMessage(Message msg) {
    for (var fn in onMessageCallback) {
      fn(this, msg);
    }
  }

  List<Function(P3p p3p, Message msg)> onMessageCallback = [];
}
