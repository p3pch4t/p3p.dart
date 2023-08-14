import 'package:dio/dio.dart';
import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/abstract.dart';

final localDio = Dio(BaseOptions(receiveDataWhenStatusError: true));

class ReachableLocal implements Reachable {
  static List<Endpoint> defaultEndpoints = [
    Endpoint(protocol: "local", host: "127.0.0.1:3893", extra: "")
  ];

  @override
  List<String> protocols = ["local", "locals"];

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
            "scheme ${endpoint.protocol} is not supported by ReachableLocal (${protocols.toString()})",
      );
    }
    final host =
        "http${endpoint.protocol == "locals" ? 's' : ''}://${endpoint.host}";
    Response? resp;
    try {
      resp = await localDio.post(
        host,
        data: message,
      );
    } catch (e) {
      print((e as DioException).response);
    }
    if (resp?.statusCode == 200) {
      await Event.tryProcess(p3p, resp?.data);
      return null;
    }
    return P3pError(code: -1, info: "unable to reach");
  }
}
