import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:p3p/p3p.dart';

enum userInfoType {
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
  final userInfoType _type;
  final int intId;

  int get id => _p3p.GetUserInfoId(_p3p.piId, intId);
  PublicKey get publicKey => switch (_type) {
        userInfoType.privateInfo => PublicKey(
            _p3p,
            _p3p.GetPrivateInfoPublicKeyArmored(_p3p.piId)
                .cast<Utf8>()
                .toDartString(),
          ),
        userInfoType.userInfo => PublicKey(
            _p3p,
            _p3p.GetUserInfoPublicKeyArmored(_p3p.piId, intId)
                .cast<Utf8>()
                .toDartString(),
          ),
      };

  set name(String name) {
    final name_ = name.toNativeUtf8().cast<Char>();
    switch (_type) {
      case userInfoType.privateInfo:
        _p3p.SetPrivateInfoUsername(_p3p.piId, name_);
      case userInfoType.userInfo:
        _p3p.SetUserInfoUsername(_p3p.piId, intId, name_);
    }
    calloc.free(name_);
  }

  String get name => switch (_type) {
        userInfoType.privateInfo =>
          _p3p.GetPrivateInfoUsername(_p3p.piId).cast<Utf8>().toDartString(),
        userInfoType.userInfo => _p3p.GetUserInfoUsername(_p3p.piId, intId)
            .cast<Utf8>()
            .toDartString(),
      };

  FileStore get fileStore {
    final result = _p3p.GetUserInfoFileStoreElements(_p3p.piId, intId)
        .cast<Utf8>()
        .toDartString();
    final idList = json.decode(result) as List<dynamic>? ?? [];
    final fseids = <FileStoreElement>[];
    for (final fseid in idList) {
      fseids.add(FileStoreElement(_p3p, intId: fseid as int));
    }
    return FileStore(files: fseids);
  }

  String get endpoint => switch (_type) {
        userInfoType.privateInfo =>
          _p3p.GetPrivateInfoEndpoint(_p3p.piId).cast<Utf8>().toDartString(),
        userInfoType.userInfo => _p3p.GetUserInfoEndpoint(_p3p.piId, intId)
            .cast<Utf8>()
            .toDartString(),
      };
  set endpoint(String endpoint) {
    final endpoint_ = endpoint.toNativeUtf8().cast<Char>();
    switch (_type) {
      case userInfoType.privateInfo:
        _p3p.SetPrivateInfoEndpoint(_p3p.piId, endpoint_);
      case userInfoType.userInfo:
        _p3p.SetUserInfoEndpoint(_p3p.piId, intId, endpoint_);
    }
    calloc.free(endpoint_);
  }

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
  List<FileStoreElement> files;
}

class FileStoreElement {
  FileStoreElement(
    this._p3p, {
    required this.intId,
  });
  final P3p _p3p;
  final int intId;
  String get localPath => _p3p.GetFileStoreElementLocalPath(_p3p.piId, intId)
      .cast<Utf8>()
      .toDartString();
  bool get isDownloaded =>
      _p3p.GetFileStoreElementIsDownloaded(_p3p.piId, intId) == 1;
  int get sizeBytes => _p3p.GetFileStoreElementSizeBytes(_p3p.piId, intId);
  File get file => File(localPath);

  String get path => _p3p.GetFileStoreElementPath(_p3p.piId, intId)
      .cast<Utf8>()
      .toDartString();
  set path(String path) {
    final newPath = path.toNativeUtf8().cast<Char>();
    _p3p.SetFileStoreElementPath(_p3p.piId, intId, newPath);
    calloc.free(newPath);
  }

  bool get isDeleted =>
      _p3p.GetFileStoreElementIsDeleted(_p3p.piId, intId) == 1;
  set isDeleted(bool? isDeleted) => _p3p.SetFileStoreElementIsDeleted(
        _p3p.piId,
        intId,
        isDeleted ?? true ? 1 : 0,
      );

  bool get shouldFetch => true;

  void updateFileContent() {
    // We don't need this function currently.
    // Why you may ask - simply because p3pgo already checks for filesystem
    // changes and automagically updates the content.
  }
}

// InternalKeyID string `json:"-"`
// Uuid          string `json:"uuid,omitempty"`
// //Path - is the in chat path, eg /Apps/Calendar.xdc
// Path string `json:"path,omitempty"`
// //LocalPath - is the filesystem path
// LocalPath string `json:"-"`
// Sha512sum string `json:"sha512sum,omitempty"`
// SizeBytes int64  `json:"sizeBytes,omitempty"`
// //	IsDeleted  bool   `json:"isDeleted,omitempty"`
// ModifyTime int64 `json:"modifyTime,omitempty"`
