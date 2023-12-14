import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:p3p/p3p.dart';
import 'package:p3p/src/generated_bindings.dart';

class QueuedEvent {
  QueuedEvent(
    this._p3p, {
    required this.id,
  });

  final P3p _p3p;
  int id;

  DateTime get createdAt => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetQueuedEventCreatedAt(_p3p.piId, id),
      );
  DateTime get updatedAt => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetQueuedEventUpdatedAt(_p3p.piId, id),
      );
  DateTime get deletedAt => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetQueuedEventDeletedAt(_p3p.piId, id),
      );

  Uint8List get body =>
      convertGoSliceToUint8List(_p3p.GetQueuedEventBody(_p3p.piId, id));
  String get endpoint =>
      _p3p.GetQueuedEventEndpoint(_p3p.piId, id).cast<Utf8>().toDartString();
  DateTime get lastRelayed => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetQueuedEventLastRelayed(_p3p.piId, id),
      );
  int get realayTries => _p3p.GetQueuedEventRelayTries(_p3p.piId, id);
}

Uint8List convertGoSliceToUint8List(GoSlice goSlice) {
  final dataPointer = Pointer<Uint8>.fromAddress(goSlice.data.address);
  final data = dataPointer.asTypedList(goSlice.len);
  return Uint8List.fromList(data);
}
