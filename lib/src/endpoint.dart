import 'package:objectbox/objectbox.dart';

@Entity()
class Endpoint {
  Endpoint({
    required this.protocol,
    required this.host,
    required this.extra,
  });
  @Id()
  int id = 0;

  String protocol;

  /// host - do not thing of http header host,
  /// let's assume that we are given following profile url
  /// local://127.0.0.1:8783/asdfevc?qwer=asd#hashpart
  /// ------->127.0.0.1:8783/asdfevc?qwer=asd<--------
  /// This would be the host part
  String host;

  String extra;
  @Property(type: PropertyType.date)
  DateTime lastReached = DateTime.fromMillisecondsSinceEpoch(0);
  int reachTriesTotal = 0;
  int reachTriesSuccess = 0;
  int get reachTriesFail => reachTriesTotal - reachTriesSuccess;

  @override
  String toString() {
    if (extra == "") return "$protocol://$host";
    return "$protocol://$host#$extra";
  }

  static Endpoint? fromString(String endpoint) {
    final urip = Uri.parse(endpoint);
    return Endpoint(
      protocol: urip.scheme,
      host: '${urip.host}${urip.path}${urip.query}:${urip.port}',
      extra: endpoint.contains('#')
          ? endpoint.substring(endpoint.indexOf('#'))
          : '',
    );
  }

  static List<Endpoint> fromStringList(List<String> endpointList) {
    final list = <Endpoint>[];

    for (var endpoint in endpointList) {
      final parsedEndpoint = Endpoint.fromString(endpoint);
      if (parsedEndpoint == null) {
        continue;
      }
      list.add(parsedEndpoint);
    }

    return list;
  }
}
