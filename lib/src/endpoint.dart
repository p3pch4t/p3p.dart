import 'package:hive/hive.dart';

part 'endpoint.g.dart';

@HiveType(typeId: 2)
class Endpoint {
  Endpoint({
    required this.protocol,
    required this.host,
    required this.extra,
  });

  @HiveField(0)
  String protocol;

  /// host - do not thing of http header host,
  /// let's assume that we are given following profile url
  /// local://127.0.0.1:8783/asdfevc?qwer=asd#hashpart
  /// ------->127.0.0.1:8783/asdfevc?qwer=asd<--------
  /// This would be the host part
  @HiveField(1)
  String host;

  @HiveField(2)
  String extra;

  @HiveField(3)
  DateTime lastReached = DateTime.fromMicrosecondsSinceEpoch(0);

  @HiveField(4)
  int reachTriesTotal = 0;

  @HiveField(5)
  int reachTriesSuccess = 0;

  int get reachTriesFail => reachTriesTotal - reachTriesSuccess;

  @override
  String toString() {
    if (extra == "") return "$protocol://$host";
    return "$protocol://$host#$extra";
  }
}
