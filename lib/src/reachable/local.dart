import 'package:dart_pg/dart_pg.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:p3p/src/endpoint.dart';
import 'package:p3p/src/error.dart';
import 'package:p3p/src/event.dart';
import 'package:p3p/src/reachable/abstract.dart';
import 'package:p3p/src/userinfo.dart';

final localDio = Dio();

class ReachableLocal implements Reachable {
  @override
  List<String> protocols = ["local", "locals"];

  @override
  Future<P3pError?> reach(Endpoint endpoint, String message,
      PrivateKey privatekey, LazyBox<UserInfo> userinfoBox) async {
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
      await Event.tryProcess(resp.data, privatekey, userinfoBox);
      return null;
    }
    return P3pError(code: -1, info: "unable to reach");
  }
}
