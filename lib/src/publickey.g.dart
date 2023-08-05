// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publickey.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PublicKeyAdapter extends TypeAdapter<PublicKey> {
  @override
  final int typeId = 1;

  @override
  PublicKey read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PublicKey(
      fingerprint: fields[1] as String,
      publickey: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PublicKey obj) {
    writer
      ..writeByte(2)
      ..writeByte(1)
      ..write(obj.fingerprint)
      ..writeByte(2)
      ..write(obj.publickey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicKeyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
