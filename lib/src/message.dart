import 'package:p3p/p3p.dart';
import 'package:ffi/ffi.dart';
import 'dart:ffi';

enum MessageType {
  unsupported,
  text,
  service,
}

class Message {
  Message(this.p3p, this.intId);

  P3p p3p;
  int intId;

  MessageType get type =>
      switch (p3p.GetMessageType(intId).cast<Utf8>().toDartString()) {
        'text' => MessageType.text,
        'service' => MessageType.service,
        'unsupported' || _ => MessageType.unsupported,
      };

  String get text => p3p.GetMessageText(intId).cast<Utf8>().toDartString();
  DateTime get dateReceived => DateTime.fromMicrosecondsSinceEpoch(
        p3p.GetMessageReceivedTimestamp(intId),
      );
  bool get incoming => p3p.GetMessageIsIncoming(intId) == 1;
}
