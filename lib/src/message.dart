import 'package:ffi/ffi.dart';
import 'package:p3p/p3p.dart';

enum MessageType {
  unsupported,
  text,
  service,
}

class Message {
  Message(this._p3p, this.intId);

  final P3p _p3p;
  int intId;

  MessageType get type => switch (
          _p3p.GetMessageType(_p3p.piId, intId).cast<Utf8>().toDartString()) {
        'text' => MessageType.text,
        'service' => MessageType.service,
        'unsupported' || _ => MessageType.unsupported,
      };

  String get text =>
      _p3p.GetMessageText(_p3p.piId, intId).cast<Utf8>().toDartString();
  DateTime get dateReceived => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetMessageReceivedTimestamp(_p3p.piId, intId),
      );
  bool get incoming => _p3p.GetMessageIsIncoming(_p3p.piId, intId) == 1;
}
