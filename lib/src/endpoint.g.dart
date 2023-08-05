// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'endpoint.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EndpointAdapter extends TypeAdapter<Endpoint> {
  @override
  final int typeId = 2;

  @override
  Endpoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Endpoint(
      protocol: fields[0] as String,
      host: fields[1] as String,
      extra: fields[2] as String,
    )
      ..lastReached = fields[3] as DateTime
      ..reachTriesTotal = fields[4] as int
      ..reachTriesSuccess = fields[5] as int;
  }

  @override
  void write(BinaryWriter writer, Endpoint obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.protocol)
      ..writeByte(1)
      ..write(obj.host)
      ..writeByte(2)
      ..write(obj.extra)
      ..writeByte(3)
      ..write(obj.lastReached)
      ..writeByte(4)
      ..write(obj.reachTriesTotal)
      ..writeByte(5)
      ..write(obj.reachTriesSuccess);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EndpointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
