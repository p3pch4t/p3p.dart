import 'dart:convert';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/abstract.dart';

final relayDio = Dio(BaseOptions(receiveDataWhenStatusError: true));

Map<String, pgp.PublicKey> pkMap = {};

class ReachableRelay implements Reachable {
  @override
  List<String> protocols = ["relay", "relays"];

  @override
  Future<P3pError?> reach(
      Endpoint endpoint,
      String message,
      pgp.PrivateKey privatekey,
      LazyBox<UserInfo> userinfoBox,
      LazyBox<Message> messageBox,
      PublicKey publicKey) async {
    if (!protocols.contains(endpoint.protocol)) {
      return P3pError(
        code: -1,
        info:
            "scheme ${endpoint.protocol} is not supported by ReachableRelay (${protocols.toString()})",
      );
    }
    final host =
        "http${endpoint.protocol == "relays" ? 's' : ''}://${endpoint.host}/${publicKey.fingerprint}";
    Response? resp;
    try {
      resp = await relayDio.post(
        host,
        options: Options(headers: {
          "gpg-auth": base64.encode(
            utf8.encode(
              await generateAuth(endpoint, privatekey),
            ),
          ),
        }),
        data: message,
      );
    } catch (e) {
      print((e as DioException).response);
    }
    if (resp?.statusCode == 200) {
      await Event.tryProcess(resp?.data, privatekey, userinfoBox, messageBox);
      return null;
    }
    return P3pError(code: -1, info: "unable to reach");
  }

  Future<String> generateAuth(
    Endpoint endpoint,
    pgp.PrivateKey privatekey,
  ) async {
    if (pkMap[endpoint.host] == null) {
      final resp = await relayDio.get(
          "http${endpoint.protocol == "relays" ? 's' : ''}://${endpoint.host}");
      pkMap[endpoint.host] =
          await pgp.OpenPGP.readPublicKey(resp.data.toString());
      print(pkMap[endpoint.host]?.fingerprint);
    }
    final publicKey = pkMap[endpoint.host];
    if (publicKey == null) {
      return "unknown auth - ${privatekey.fingerprint}";
    }
    final message = {
      "version": 0,
      "date": DateTime.now().toUtc().microsecondsSinceEpoch
    };
    final messageText = JsonEncoder.withIndent('    ').convert(message);
    final msg = await pgp.OpenPGP.encrypt(
      pgp.Message.createTextMessage(messageText),
      encryptionKeys: [publicKey],
      signingKeys: [privatekey],
    );
    return msg.armor();
  }
}
