import 'dart:convert';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:dio/dio.dart';
import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/abstract.dart';

final relayDio = Dio(BaseOptions(receiveDataWhenStatusError: true));

Map<String, pgp.PublicKey> pkMap = {};

class ReachableRelay implements Reachable {
  static Future<void> getAndProcessEvents(P3p p3p) async {
    for (var endp in defaultEndpoints) {
      final resp = await _contactRelay(
        endp: endp,
        httpHostname:
            "${_hostnameRoot(endp)}/${List.filled(p3p.privateKey.fingerprint.length, '0').join("")}",
        p3p: p3p,
        message: (await pgp.OpenPGP.encrypt(
          pgp.Message.createTextMessage("{}"),
          signingKeys: [p3p.privateKey],
          encryptionKeys: [p3p.privateKey.toPublic],
        ))
            .armor(),
      );
      if (resp == null) {
        print(
            "ReachableRelay: getEvents(): unable to reach ${endp.toString()}");
        continue;
      }
      Event.tryProcess(p3p, resp.data);
    }
  }

  static List<Endpoint> defaultEndpoints = [
    Endpoint(protocol: "relay", host: "mrcyjanek.net:3847", extra: ""),
  ];

  @override
  List<String> protocols = ["relay", "relays"];

  @override
  Future<P3pError?> reach({
    required P3p p3p,
    required Endpoint endpoint,
    required String message,
    required PublicKey publicKey,
  }) async {
    if (!protocols.contains(endpoint.protocol)) {
      return P3pError(
        code: -1,
        info:
            "scheme ${endpoint.protocol} is not supported by ReachableRelay (${protocols.toString()})",
      );
    }
    Response? resp = await _contactRelay(
      endp: endpoint,
      httpHostname: _httpHostname(endpoint, publicKey),
      p3p: p3p,
      message: message,
    );
    if (resp == null) {
      print("ReachableRelay: reach(): unable to reach ${endpoint.toString()}");
      return P3pError(code: -1, info: "unable to reach 1");
    }

    if (resp.statusCode == 200) {
      await Event.tryProcess(p3p, resp.data);
      return null;
    }
    return P3pError(code: -1, info: "unable to reach 2");
  }

  static Future<String> generateAuth(
    Endpoint endpoint,
    pgp.PrivateKey privatekey,
  ) async {
    if (pkMap[endpoint.host] == null) {
      final resp = await relayDio.get(_hostnameRoot(endpoint));
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

  static Future<Response?> _contactRelay(
      {required Endpoint endp,
      required String httpHostname,
      required P3p p3p,
      dynamic message}) async {
    assert(message != null);
    try {
      final resp = await relayDio.post(
        httpHostname,
        options: Options(headers: await _getHeaders(endp, p3p)),
        data: message,
      );
      return resp;
    } catch (e) {
      if (e is DioException) {
        print((e).response);
        return e.response;
      } else {
        print(e);
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> _getHeaders(
      Endpoint endp, P3p p3p) async {
    return {
      "gpg-auth": base64.encode(
        utf8.encode(
          await generateAuth(endp, p3p.privateKey),
        ),
      ),
    };
  }

  static String _httpHostname(Endpoint endp, PublicKey publicKey) =>
      "${_hostnameRoot(endp)}/${publicKey.fingerprint}";
  static String _hostnameRoot(Endpoint endp) =>
      "http${endp.protocol == "relays" ? 's' : ''}://${endp.host}";
}
