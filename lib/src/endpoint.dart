/// Contains information about where can we reach somebody
class Endpoint {
  ///
  Endpoint({
    required this.protocol,
    required this.host,
    required this.extra,
    this.id = -1,
    this.reachTriesTotal = 0,
    this.reachTriesSuccess = 0,
  });

  /// id, -1 means to make a new insert to db.
  int id = -1;

  /// local or i2p or tor
  String protocol;

  /// host - do not think of http header host,
  /// let's assume that we are given following profile url
  /// local://127.0.0.1:8783/asdfevc?qwer=asd#hashpart
  /// ------->127.0.0.1:8783/asdfevc?qwer=asd<--------
  /// This would be the host part
  String host;

  /// so called "hashpart"
  String extra;

  /// when did we have last successful reach for this relay?
  DateTime lastReached = DateTime.fromMicrosecondsSinceEpoch(0);

  /// how many times did we try to contact this relay, in total.
  int reachTriesTotal = 0;

  /// how many times did we successfully contacted this relay.
  int reachTriesSuccess = 0;

  /// how many times did we fail to contact this relay.
  int get reachTriesFail => reachTriesTotal - reachTriesSuccess;

  @override
  String toString() {
    if (extra == '') return '$protocol://$host';
    return '$protocol://$host#$extra';
  }

  /// Create Endpoint? from a proper endpoint String.
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

  /// call fromString but in a loop.
  static List<Endpoint> fromStringList(List<String> endpointList) {
    final list = <Endpoint>[];

    for (final endpoint in endpointList) {
      final parsedEndpoint = Endpoint.fromString(endpoint);
      if (parsedEndpoint == null) {
        continue;
      }
      list.add(parsedEndpoint);
    }

    return list;
  }

  /// convert endpoints to a List<String> that can be parsed back using
  /// Endpoint.fromStringList
  static List<String> toStringList(List<Endpoint> endpointList) {
    final list = <String>[];
    for (final element in endpointList) {
      list.add(element.toString());
    }
    return list;
  }
}
