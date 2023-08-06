import 'dart:convert';

import 'package:hive/hive.dart';
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
    required this.sessionName,
    required this.privateKey,
  });

  final String sessionName;
  final pgp.PrivateKey privateKey;

  late final LazyBox<Endpoint> endpointBox;
  late final LazyBox<Event> eventBox;
  late final LazyBox<PublicKey> publickeyBox;
  late final LazyBox<UserInfo> userinfoBox;

  static Future<P3p> createSession(
    String storePath,
    String sessionName,
    String privateKey,
    String privateKeyPassword,
  ) async {
    Hive.init(storePath);
    Hive.registerAdapter(EndpointAdapter());
    Hive.registerAdapter(PublicKeyAdapter());
    Hive.registerAdapter(UserInfoAdapter());
    Hive.registerAdapter(EventAdapter());
    Hive.registerAdapter(EventTypeAdapter());
    final p3p = P3p(
      sessionName: sessionName,
      privateKey: await (await pgp.OpenPGP.readPrivateKey(privateKey))
          .decrypt(privateKeyPassword),
    )
      ..endpointBox = await Hive.openLazyBox<Endpoint>("$sessionName.endpoint")
      ..eventBox = await Hive.openLazyBox<Event>("$sessionName.event")
      ..publickeyBox =
          await Hive.openLazyBox<PublicKey>("$sessionName.publickey")
      ..userinfoBox = await Hive.openLazyBox<UserInfo>("$sessionName.userinfo");
    await p3p.listen();
    return p3p;
  }

  Future<UserInfo> getSelfInfo() async {
    return UserInfo(
      publicKey: await PublicKey.create(privateKey.toPublic.armor()),
      endpoint: [
        Endpoint(protocol: "local", host: "127.0.0.1:3893", extra: ""),
      ],
    );
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
    return P3pError(code: -1, info: "not implemented");
  }

  getChats() {}

  getUnread() {}

  Future<void> listen() async {
    var router = Router();
    router.post("/", (Request request) async {
      final body = await request.readAsString();
      final userI =
          await Event.tryProcess(body, privateKey, publickeyBox, userinfoBox);
      if (userI == null) {
        return Response(
          404,
          body: JsonEncoder.withIndent('    ').convert(
            [
              {
                "type": "introduce.request",
                "data": null,
              }
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
  }
}
