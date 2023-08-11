import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/abstract.dart';

final localDio = Dio(BaseOptions(receiveDataWhenStatusError: true));

class ReachableLocal implements Reachable {
  @override
  List<String> protocols = ["local", "locals"];

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
      await Event.tryProcess(resp?.data, privatekey, userinfoBox, messageBox);
      return null;
    }
    return P3pError(code: -1, info: "unable to reach");
  }
}
