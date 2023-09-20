import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/abstract.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shell_router;

final _localDio = Dio(BaseOptions(receiveDataWhenStatusError: true));

/// ReachableI2p contains logic about how we can reach p2p members of the
/// network over eepsite addresses.
class ReachableI2p implements Reachable {
  /// ReachableI2p is special and requires some configuration before it can be
  /// usable.
  ReachableI2p({
    required this.eepsiteAddress,
  });

  /// how can we be reached over i2p?
  String eepsiteAddress;

  // You have probably expected to see getListenRouter here, but this is not
  // the case. We will use ReachableLocal's http server.
  // static shell_router.Router? getListenRouter(P3p p3p)

  /// Get default endpoints, taking user config into account.
  static List<Endpoint> getDefaultEndpoints(P3p p3p) {
    // ignore: deprecated_member_use_from_same_package
    return [];
  }

  @override
  List<String> protocols = ['i2p'];

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
        info: 'scheme ${endpoint.protocol} is not '
            'supported by ReachableI2p ($protocols)',
      );
    }
    final localhostRegexp =
        RegExp(r'/^127\.(([1-9]?\d|[12]\d\d)\.){2}([1-9]?\d|[12]\d\d)$/');
    final host =
        "http${endpoint.protocol == "locals" ? 's' : ''}://${endpoint.host}";
    if (!localhostRegexp.hasMatch(endpoint.host)) {
      p3p.print('Refusing to connect to ${endpoint.host}. It is not part of '
          '127.0.0.0/8 subnet');
      return P3pError(
        code: -1,
        info: 'Refusing to connect to ${endpoint.host}. It is not part of '
            '127.0.0.0/8 subnet',
      );
    }
    Response<String>? resp;
    try {
      resp = await _localDio.post(
        host,
        data: message,
        options: Options(responseType: ResponseType.plain),
      );
    } catch (e) {
      p3p.print((e as DioException).response);
    }
    if (resp?.statusCode == 200) {
      await Event.tryProcess(p3p, resp!.data!);
      return null;
    }
    return P3pError(code: -1, info: 'unable to reach');
  }
}
