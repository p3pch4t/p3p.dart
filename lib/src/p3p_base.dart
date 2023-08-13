import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:p3p/src/chat.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/error.dart';
import 'package:p3p/src/event.dart';
import 'package:p3p/src/filestore.dart';
import 'package:p3p/src/publickey.dart';
import 'package:p3p/src/reachable/relay.dart';
import 'package:p3p/src/userinfo.dart';
import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:path/path.dart' as p;

class P3p {
  P3p({
    required this.privateKey,
    required this.fileStorePath,
  });

  final pgp.PrivateKey privateKey;
  final String fileStorePath;

  late final LazyBox<UserInfo> userinfoBox;
  late final LazyBox<Message> messageBox;
  late final LazyBox<FileStoreElement> filestoreelementBox;

  static Future<P3p> createSession(
    String storePath,
    String privateKey,
    String privateKeyPassword,
  ) async {
    print("p3p: using $storePath");
    Hive.init(p.join(storePath, 'db'));

    /* 0 */ Hive.registerAdapter(UserInfoAdapter());
    /* 1 */ Hive.registerAdapter(PublicKeyAdapter());
    /* 2 */ Hive.registerAdapter(EndpointAdapter());
    /* 3 */ Hive.registerAdapter(EventAdapter());
    /* 4 */ Hive.registerAdapter(EventTypeAdapter());
    /* 5 */ Hive.registerAdapter(MessageAdapter());
    /* 6 */ Hive.registerAdapter(MessageTypeAdapter());
    /* 8 */ Hive.registerAdapter(FileStoreElementAdapter());

    final privkey = await (await pgp.OpenPGP.readPrivateKey(privateKey))
        .decrypt(privateKeyPassword);

    final p3p = P3p(
      privateKey: privkey,
      fileStorePath: p.join(storePath, 'files'),
    )
      ..userinfoBox = await Hive.openLazyBox<UserInfo>(
        "${privkey.fingerprint}.userinfo",
      )
      ..messageBox = await Hive.openLazyBox<Message>(
        "${privkey.fingerprint}.message",
      )
      ..filestoreelementBox = await Hive.openLazyBox<FileStoreElement>(
        "${privkey.fingerprint}.filestoreelement",
      );
    await p3p.listen();
    p3p.scheduleTasks();
    return p3p;
  }

  Future<UserInfo> getSelfInfo() async {
    UserInfo? useri = await userinfoBox.get(privateKey.toPublic.fingerprint);
    useri ??= UserInfo(
      publicKey: (await PublicKey.create(privateKey.toPublic.armor()))!,
      endpoint: [
        // TODO: ...ReachableLocal.defaultEndpoints,
        ...ReachableRelay.defaultEndpoints,
      ],
    )..name = "localuser [${privateKey.keyID}]";
    await userinfoBox.put(useri.publicKey.fingerprint, useri);
    return useri;
  }

  Future<P3pError?> sendMessage(UserInfo destination, String text,
      {MessageType type = MessageType.text}) async {
    final evt = Event(
      type: EventType.message,
      data: EventMessage(
        text: text,
        type: type,
      ).toJson(),
    );
    destination.addEvent(evt, userinfoBox);
    final self = await getSelfInfo();
    self.addMessage(
        Message.fromEvent(evt, false, destination.publicKey.fingerprint)!,
        messageBox);
    destination.relayEvents(privateKey, userinfoBox, messageBox,
        filestoreelementBox, fileStorePath);
    return null;
  }

  Future<UserInfo?> getUserByKey(String armored) async {
    final pubkey = await pgp.OpenPGP.readPublicKey(armored);
    return userinfoBox.get(pubkey.fingerprint);
  }

  Future<List<UserInfo>> getUsers() async {
    final uiList = <UserInfo>[];
    for (var uiKey in userinfoBox.keys) {
      final ui = await userinfoBox.get(uiKey);
      if (ui == null) {
        continue;
      }
      uiList.add(ui);
    }
    uiList.sort((ui, ui2) =>
        ui.lastMessage.microsecondsSinceEpoch -
        ui2.lastMessage.microsecondsSinceEpoch);
    return uiList;
  }

  Future<void> listen() async {
    var router = Router();
    router.post("/", (Request request) async {
      final body = await request.readAsString();
      final userI = await Event.tryProcess(body, privateKey, userinfoBox,
          messageBox, filestoreelementBox, fileStorePath);
      if (userI == null) {
        return Response(
          404,
          body: JsonEncoder.withIndent('    ').convert(
            [
              Event(
                type: EventType.introduceRequest,
                data: EventIntroduceRequest(
                  endpoint: (await getSelfInfo()).endpoint,
                  publickey: privateKey.toPublic,
                ).toJson(),
              ).toJson(),
            ],
          ),
        );
      }
      return Response(
        200,
        body: await userI.relayEventsString(privateKey, userinfoBox),
      );
    });
    try {
      final server = await io.serve(router, '0.0.0.0', 3893);

      print('${server.address.address}:${server.port}');
    } catch (e) {
      print("failed to start server: $e");
    }
  }

  void scheduleTasks() async {
    // TODO: put them in a timer or something.
    final si = (await getSelfInfo());
    for (var key in userinfoBox.keys) {
      final ui = await userinfoBox.get(key);
      if (ui == null) continue;
    }
    Timer.periodic(Duration(seconds: 5), (Timer t) async {
      for (var key in userinfoBox.keys) {
        var ui = await userinfoBox.get(key);
        if (ui == null) {
          continue;
        }
        ui.relayEvents(
          privateKey,
          userinfoBox,
          messageBox,
          filestoreelementBox,
          fileStorePath,
        );
        ui = await userinfoBox.get(key);
        if (ui == null) {
          continue;
        }
        final diff = DateTime.now().difference(ui.lastIntroduce).inMinutes;
        print('p3p: ${ui.publicKey.fingerprint} : scheduleTasks diff = $diff');
        if (diff > 60) {
          ui.addEvent(
              Event(
                type: EventType.introduce,
                data: EventIntroduce(
                  endpoint: si.endpoint,
                  fselm: await ui.fileStore
                      .getFileStoreElement(filestoreelementBox),
                  publickey: privateKey.toPublic,
                  username: si.name ?? "unknown name",
                ).toJson(),
              ),
              userinfoBox);
        }
      }
    });
  }
}
