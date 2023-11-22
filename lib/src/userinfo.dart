import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:p3p/p3p.dart';

enum userInfoType {
  userInfo,
  privateInfo,
}

class UserInfo {
  UserInfo(
    this._p3p,
    this._type,
    this.intId,
  );
  final P3p _p3p;
  final userInfoType _type;
  final int intId;

  int get id => _p3p.GetUserInfoId(intId);
  PublicKey get publicKey => switch (_type) {
        userInfoType.privateInfo => PublicKey(
            _p3p,
            _p3p.GetPrivateInfoPublicKeyArmored().cast<Utf8>().toDartString(),
          ),
        userInfoType.userInfo => PublicKey(
            _p3p,
            _p3p.GetUserInfoPublicKeyArmored(intId).cast<Utf8>().toDartString(),
          ),
      };

  set name(String name) => switch (_type) {
        userInfoType.privateInfo =>
          _p3p.SetPrivateInfoUsername(name.toNativeUtf8().cast<Char>()),
        userInfoType.userInfo =>
          _p3p.SetUserInfoUsername(intId, name.toNativeUtf8().cast<Char>()),
      };
  String get name => switch (_type) {
        userInfoType.privateInfo =>
          _p3p.GetPrivateInfoUsername().cast<Utf8>().toDartString(),
        userInfoType.userInfo =>
          _p3p.GetUserInfoUsername(intId).cast<Utf8>().toDartString(),
      };

  FileStore get fileStore => throw UnimplementedError();

  String get endpoint => switch (_type) {
        userInfoType.privateInfo =>
          _p3p.GetPrivateInfoEndpoint().cast<Utf8>().toDartString(),
        userInfoType.userInfo =>
          _p3p.GetUserInfoEndpoint(intId).cast<Utf8>().toDartString(),
      };
  set endpoint(String endpoint) => switch (_type) {
        userInfoType.privateInfo =>
          _p3p.SetPrivateInfoEndpoint(endpoint.toNativeUtf8().cast<Char>()),
        userInfoType.userInfo =>
          _p3p.SetUserInfoEndpoint(intId, endpoint.toNativeUtf8().cast<Char>()),
      };
}

class PublicKey {
  PublicKey(this._p3p, this.armored);
  final P3p _p3p;
  String get fingerprint =>
      _p3p.GetPublicKeyFingerprint(armored.toNativeUtf8().cast<Char>())
          .cast<Utf8>()
          .toDartString();
  final String armored;
}

class FileStore {}

class FileStoreElement {
  String get localPath => throw UnimplementedError();
  int get downloadedSizeBytes => throw UnimplementedError();
  int get sizeBytes => throw UnimplementedError();
  File get file => throw UnimplementedError();

  String get path => throw UnimplementedError();
  set path(String path) => throw UnimplementedError();

  bool get isDeleted => throw UnimplementedError();
  set isDeleted(bool? isDeleted) => throw UnimplementedError();

  bool get shouldFetch => throw UnimplementedError();
  set shouldFetch(bool? shouldFetch) => throw UnimplementedError();
}
