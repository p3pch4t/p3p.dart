import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/abstract.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shell_router;

final _localDio = Dio(BaseOptions(receiveDataWhenStatusError: true));

/// ReachableLocal contains logic about how we can reach p2p members of the
/// network.
// TODO(mrcyjanek): It must be clearly set wether or not to allow local.
class ReachableLocal implements Reachable {
  /// Return's listenable router that is used when P3p is initialised with
  /// listen: true option, or listen() is called manually.
  static shell_router.Router getListenRouter(P3p p3p) {
    final router = shell_router.Router()
      ..post('/', (shelf.Request request) async {
        final body = await request.readAsString();
        final userI = await Event.tryProcess(p3p, body);
        if (userI == null) {
          return shelf.Response(
            404,
            body: const JsonEncoder.withIndent('    ').convert(
              [
                Event(
                  eventType: EventType.introduceRequest,
                  data: EventIntroduceRequest(
                    endpoint: (await p3p.getSelfInfo()).endpoint,
                    publickey: p3p.privateKey.toPublic,
                  ),
                ).toJson(),
              ],
            ),
          );
        }
        return shelf.Response(
          200,
          // ignore: deprecated_member_use_from_same_package
          body: await userI.relayEventsString(p3p),
        );
      });
    return router;
  }

  /// List<Endpoint> that contains endpoints that are accessible by default
  @Deprecated('use getDefaultEndpoints(P3p) instead')
  static List<Endpoint> defaultEndpoints = [
    Endpoint(protocol: 'local', host: '127.0.0.1:3893', extra: ''),
  ];

  /// Get default endpoints, taking user config into account.
  static List<Endpoint> getDefaultEndpoints(P3p p3p) {
    // ignore: deprecated_member_use_from_same_package
    return defaultEndpoints;
  }

  @override
  List<String> protocols = ['local', 'locals'];

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
            'supported by ReachableLocal ($protocols)',
      );
    }
    final host =
        "http${endpoint.protocol == "locals" ? 's' : ''}://${endpoint.host}";
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
