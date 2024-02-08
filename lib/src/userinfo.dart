import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:p3p/p3p.dart';
import 'package:p3p/src/endpoint_stats.dart';

enum UserInfoType {
  userInfo,
  privateInfo,
}

class DiscoveredUserInfo {
  DiscoveredUserInfo(
    this._p3p, {
    required this.name,
    required this.bio,
    required this.publickey,
    required this.endpoint,
  });
  // We don't need it now, but since it is part of the p3p.dart, and we use
  // go as the backend it makes sense to include it here, just to not have
  // to fix issues once this becomes required.
  // ignore: unused_field
  final P3p _p3p;

  final String name;
  final String bio;
  final String publickey;
  final String endpoint;
}

class UserInfo {
  UserInfo(
    this._p3p,
    this._type,
    this.intId,
  );
  final P3p _p3p;
  final UserInfoType _type;
  final int intId;

  int get id => _p3p.GetUserInfoId(_p3p.piId, intId);
  PublicKey get publicKey => switch (_type) {
        UserInfoType.privateInfo => PublicKey(
            _p3p,
            _p3p.GetPrivateInfoPublicKeyArmored(_p3p.piId)
                .cast<Utf8>()
                .toDartString(),
          ),
        UserInfoType.userInfo => PublicKey(
            _p3p,
            _p3p.GetUserInfoPublicKeyArmored(_p3p.piId, intId)
                .cast<Utf8>()
                .toDartString(),
          ),
      };

  set name(String name) {
    final name_ = name.toNativeUtf8().cast<Char>();
    switch (_type) {
      case UserInfoType.privateInfo:
        _p3p.SetPrivateInfoUsername(_p3p.piId, name_);
      case UserInfoType.userInfo:
        _p3p.SetUserInfoUsername(_p3p.piId, intId, name_);
    }
    calloc.free(name_);
  }

  String get name => switch (_type) {
        UserInfoType.privateInfo =>
          _p3p.GetPrivateInfoUsername(_p3p.piId).cast<Utf8>().toDartString(),
        UserInfoType.userInfo => _p3p.GetUserInfoUsername(_p3p.piId, intId)
            .cast<Utf8>()
            .toDartString(),
      };

  FileStore get sharedFiles {
    final result =
        _p3p.GetSharedFilesIDs(_p3p.piId, intId).cast<Utf8>().toDartString();
    final idList = json.decode(result) as List<dynamic>? ?? [];
    final fseids = <SharedFile>[];
    for (final fseid in idList) {
      fseids.add(SharedFile(_p3p, intId: fseid as int));
    }
    return FileStore(files: fseids);
  }

  String get endpoint => switch (_type) {
        UserInfoType.privateInfo =>
          _p3p.GetPrivateInfoEndpoint(_p3p.piId).cast<Utf8>().toDartString(),
        UserInfoType.userInfo => _p3p.GetUserInfoEndpoint(_p3p.piId, intId)
            .cast<Utf8>()
            .toDartString(),
      };
  set endpoint(String endpoint) {
    final endpoint_ = endpoint.toNativeUtf8().cast<Char>();
    switch (_type) {
      case UserInfoType.privateInfo:
        _p3p.SetPrivateInfoEndpoint(_p3p.piId, endpoint_);
      case UserInfoType.userInfo:
        _p3p.SetUserInfoEndpoint(_p3p.piId, intId, endpoint_);
    }
    calloc.free(endpoint_);
  }

  EndpointStats get endpointStats =>
      EndpointStats(_p3p, id: _p3p.GetUserInfoEndpointStats(_p3p.piId, intId));

  bool forceSendIntroduceEvent() =>
      _p3p.ForceSendIntroduceEvent(_p3p.piId, intId) == 1;
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

class FileStore {
  FileStore({
    required this.files,
  });
  final List<SharedFile> files;
}

class SharedFile {
  SharedFile(
    this._p3p, {
    required this.intId,
  });
  final P3p _p3p;
  final int intId;

  DateTime get createdAt => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetSharedFileCreatedAt(_p3p.piId, intId),
      );

  DateTime get updatedAt => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetSharedFileUpdatedAt(_p3p.piId, intId),
      );

  DateTime get deletedAt => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetSharedFileDeletedAt(_p3p.piId, intId),
      );

  String get sharedFor =>
      _p3p.GetSharedFileSharedFor(_p3p.piId, intId).cast<Utf8>().toDartString();

  String get sha512sum =>
      _p3p.GetSharedFileSha512Sum(_p3p.piId, intId).cast<Utf8>().toDartString();

  DateTime get lastEdit => DateTime.fromMicrosecondsSinceEpoch(
        _p3p.GetSharedFileLastEdit(_p3p.piId, intId),
      );
  String get filePath =>
      _p3p.GetSharedFileFilePath(_p3p.piId, intId).cast<Utf8>().toDartString();

  String get localFilePath => _p3p.GetSharedFileLocalFilePath(_p3p.piId, intId)
      .cast<Utf8>()
      .toDartString();

  void delete() {
    _p3p.DeleteSharedFile(_p3p.piId, intId);
  }
}
