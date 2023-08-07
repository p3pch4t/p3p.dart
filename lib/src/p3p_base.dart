import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:p3p/src/chat.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/error.dart';
import 'package:p3p/src/event.dart';
import 'package:p3p/src/publickey.dart';
import 'package:p3p/src/userinfo.dart';
import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

class P3p {
  P3p({
    required this.privateKey,
  });

  final pgp.PrivateKey privateKey;

  late final LazyBox<UserInfo> userinfoBox;

  static Future<P3p> createSession(
    String storePath,
    String privateKey,
    String privateKeyPassword,
  ) async {
    Hive.init(storePath);
    /* 0 */ Hive.registerAdapter(UserInfoAdapter());
    /* 1 */ Hive.registerAdapter(PublicKeyAdapter());
    /* 2 */ Hive.registerAdapter(EndpointAdapter());
    /* 3 */ Hive.registerAdapter(EventAdapter());
    /* 4 */ Hive.registerAdapter(EventTypeAdapter());
    /* 5 */ Hive.registerAdapter(MessageAdapter());
    /* 6 */ Hive.registerAdapter(MessageTypeAdapter());

    final privkey = await (await pgp.OpenPGP.readPrivateKey(privateKey))
        .decrypt(privateKeyPassword);

    final p3p = P3p(
      privateKey: privkey,
    )..userinfoBox = await Hive.openLazyBox<UserInfo>(
        "${privkey.fingerprint}.userinfo",
      );
    await p3p.listen();
    return p3p;
  }

  Future<UserInfo> getSelfInfo() async {
    final useri = UserInfo(
      publicKey: await PublicKey.create(privateKey.toPublic.armor()),
      endpoint: [
        Endpoint(protocol: "local", host: "127.0.0.1:3893", extra: ""),
      ],
      name: "localuser",
    );
    await userinfoBox.put(useri.publicKey.fingerprint, useri);
    return useri;
  }

  Future<P3pError?> sendMessage(
      UserInfo destination, String text, Map<String, dynamic>? extra) async {
    extra ??= {};
    final evt = Event(
      type: EventType.message,
      data: {
        "text": text,
      },
    );
    destination.addEvent(evt, userinfoBox);
    await destination.relayEvents(privateKey, userinfoBox);
    return null;
  }

  Future<void> listen() async {
    var router = Router();
    router.post("/", (Request request) async {
      final body = await request.readAsString();
      final userI = await Event.tryProcess(body, privateKey, userinfoBox);
      if (userI == null) {
        return Response(
          404,
          body: JsonEncoder.withIndent('    ').convert(
            [
              Event(type: EventType.introduceRequest, data: {}),
            ],
          ),
        );
      }
      return Response(
        200,
        body: await userI.relayEventsString(privateKey, userinfoBox),
      );
    });
    final server = await io.serve(router, '0.0.0.0', 3893);
    print('${server.address.address}:${server.port}');
  }
}
