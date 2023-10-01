import 'dart:convert';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:dio/dio.dart';
import 'package:p3p/p3p.dart';

final _relayDio = Dio(BaseOptions(receiveDataWhenStatusError: true));

Map<String, pgp.PublicKey> _pkMap = {};

/// Relay-based communication
class ReachableRelay implements Reachable {
  /// Contact all relays, fetch events and send events to them.
  static Future<void> getAndProcessEvents(P3p p3p) async {
    for (final endp in getDefaultEndpoints(p3p)) {
      final resp = await _contactRelay(
        endp: endp,
        httpHostname:
            "${_hostnameRoot(endp)}/${List.filled(p3p.privateKey.fingerprint.length, '0').join()}",
        p3p: p3p,
        message: (await pgp.OpenPGP.encrypt(
          pgp.Message.createTextMessage('{}'),
          signingKeys: [p3p.privateKey],
          encryptionKeys: [p3p.privateKey.toPublic],
        ))
            .armor(),
      );
      if (resp == null) {
        p3p.print(
          'ReachableRelay: getEvents(): unable to reach $endp 0',
        );
        continue;
      }
      await Event.tryProcess(p3p, resp.data!);
    }
  }

  static final List<Endpoint> _defaultEndpoints = [
    Endpoint(protocol: 'relay', host: 'mrcyjanek.net:3847', extra: ''),
  ];

  /// Get all endpoints that are available for current P3p instance.
  static List<Endpoint> getDefaultEndpoints(P3p p3p) {
    // ignore: deprecated_member_use_from_same_package
    return _defaultEndpoints;
  }

  @override
  List<String> protocols = ['relay', 'relays', 'i2p'];

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
        info: 'scheme ${endpoint.protocol} is not supported '
            'by ReachableRelay ($protocols)',
      );
    }
    final resp = await _contactRelay(
      endp: endpoint,
      httpHostname: _httpHostname(endpoint, publicKey),
      p3p: p3p,
      message: message,
    );
    if (resp == null) {
      p3p.print(
        'ReachableRelay: reach(): unable to reach $endpoint -1',
      );
      return P3pError(code: -1, info: 'unable to reach 1');
    }

    if (resp.statusCode == 200) {
      await Event.tryProcess(p3p, resp.data!);
      return null;
    }
    return P3pError(code: -1, info: 'unable to reach 2');
  }

  /// Relays temporairly require some extra HTTP Header to function,
  /// generateAuth is a temporary way to solve them.
  /// NOTE: This is not properly resolved in p3prelay
  static Future<String> generateAuth(
    Endpoint endpoint,
    pgp.PrivateKey privatekey,
  ) async {
    if (_pkMap[endpoint.host] == null) {
      final resp = await _relayDio.get<String>(
        _hostnameRoot(endpoint),
        options: Options(responseType: ResponseType.plain),
      );
      _pkMap[endpoint.host] = await pgp.OpenPGP.readPublicKey(resp.data!);
    }
    final publicKey = _pkMap[endpoint.host];
    if (publicKey == null) {
      return 'unknown auth - ${privatekey.fingerprint}';
    }
    final message = {
      'version': 0,
      'date': DateTime.now().toUtc().microsecondsSinceEpoch,
    };
    final messageText = const JsonEncoder.withIndent('    ').convert(message);
    final msg = await pgp.OpenPGP.encrypt(
      pgp.Message.createTextMessage(messageText),
      encryptionKeys: [publicKey],
      signingKeys: [privatekey],
    );
    return msg.armor();
  }

  static Future<Response<String>?> _contactRelay({
    required Endpoint endp,
    required String httpHostname,
    required P3p p3p,
    String? message,
  }) async {
    try {
      final resp = await _relayDio.post<String>(
        httpHostname,
        options: Options(
          headers: await _getHeaders(endp, p3p),
          responseType: ResponseType.plain,
        ),
        data: message,
      );
      return resp;
    } catch (e) {
      if (e is DioException) {
        p3p.print(e.response);
        return null;
      } else {
        p3p.print(e);
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> _getHeaders(
    Endpoint endp,
    P3p p3p,
  ) async {
    return {
      'gpg-auth': base64.encode(
        utf8.encode(
          await generateAuth(endp, p3p.privateKey),
        ),
      ),
      if (endp.protocol == 'i2p')
        'relay-host': endp.toString().replaceAll('i2p://', 'http://'),
    };
  }

  static String _httpHostname(Endpoint endp, PublicKey publicKey) =>
      '${_hostnameRoot(endp)}/${publicKey.fingerprint}';
  static String _hostnameRoot(Endpoint endp) =>
      "http${endp.protocol == "relays" ? 's' : ''}://${endp.host}";
}
