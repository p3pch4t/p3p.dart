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

  FileStore get fileStore {
    final result =
        _p3p.GetUserInfoFileStoreElements(intId).cast<Utf8>().toDartString();
    final idList = json.decode(result) as List<dynamic>? ?? [];
    final fseids = <FileStoreElement>[];
    for (final fseid in idList) {
      fseids.add(FileStoreElement(_p3p, intId: fseid as int));
    }
    return FileStore(files: fseids);
  }

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

  bool forceSendIntroduceEvent() => _p3p.ForceSendIntroduceEvent(intId) == 1;
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
  String get localPath =>
      _p3p.GetFileStoreElementLocalPath(intId).cast<Utf8>().toDartString();
  bool get isDownloaded => _p3p.GetFileStoreElementIsDownloaded(intId) == 1;
  int get sizeBytes => _p3p.GetFileStoreElementSizeBytes(intId);
  File get file => File(localPath);

  String get path =>
      _p3p.GetFileStoreElementPath(intId).cast<Utf8>().toDartString();
  set path(String path) {
    final newPath = path.toNativeUtf8().cast<Char>();
    _p3p.SetFileStoreElementPath(intId, newPath);
    calloc.free(newPath);
  }

  bool get isDeleted => _p3p.GetFileStoreElementIsDeleted(intId) == 1;
  set isDeleted(bool? isDeleted) =>
      _p3p.SetFileStoreElementIsDeleted(intId, isDeleted ?? true ? 1 : 0);

  bool get shouldFetch => true;
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