import 'package:dio/dio.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/error.dart';
import 'package:p3p/src/reachable/abstract.dart';

final localDio = Dio();

class ReachableLocal implements Reachable {
  @override
  List<String> protocols = ["local", "locals"];

  @override
  Future<P3pError?> reach(Endpoint endpoint, String message) async {
    if (!protocols.contains(endpoint.protocol)) {
      return P3pError(
        code: -1,
        info:
            "scheme ${endpoint.protocol} is not supported by ReachableLocal (${protocols.toString()})",
      );
    }
    final host =
        "http${endpoint.protocol == "locals" ? 's' : ''}://${endpoint.host}";
    final resp = await localDio.post(host, data: message);
    if (resp.statusCode == 200) {
      return null;
    }
    return P3pError(code: -1, info: "unable to reach");
  }
}
