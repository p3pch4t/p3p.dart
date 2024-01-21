import 'package:ffi/ffi.dart';
import 'package:p3p/p3p.dart';

class EndpointStats {
  EndpointStats(
    this._p3p, {
    required this.id,
  });
  final P3p _p3p;
  int id;

  DateTime get createdAt => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetEndpointStatsCreatedAt(_p3p.piId, id),
      );
  DateTime get updatedAt => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetEndpointStatsUpdatedAt(_p3p.piId, id),
      );
  DateTime get deletedAt => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetEndpointStatsDeletedAt(_p3p.piId, id),
      );
  String get endpoint =>
      _p3p.GetEndpointStatsEndpoint(_p3p.piId, id).cast<Utf8>().toDartString();

  DateTime get LastContactIn => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetEndpointStatsLastContactIn(_p3p.piId, id),
      );
  DateTime get LastContactOut => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetEndpointStatsLastContactOut(_p3p.piId, id),
      );
  int get failInRow => _p3p.GetEndpointStatsFailInRow(_p3p.piId, id);
  int get currentDelay => _p3p.GetEndpointStatsCurrentDelay(_p3p.piId, id);
}
