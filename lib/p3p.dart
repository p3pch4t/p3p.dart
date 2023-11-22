/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

import 'dart:convert';

import 'package:p3p/src/generated_bindings.dart';
import 'package:p3p/src/message.dart';
import 'package:p3p/src/userinfo.dart';
import 'package:ffi/ffi.dart';
import 'dart:ffi';

export 'src/userinfo.dart';
export 'src/message.dart';

/// getP3pGo - start p3pgo library, and return it's object.
P3p getP3p(String? libPath) {
  if (libPath == null) {
    return P3p(
      DynamicLibrary.open(
        '/home/user/go/src/git.mrcyjanek.net/p3pch4t/p3pgo/build/api.so',
      ),
    );
  }
  return P3p(DynamicLibrary.open(libPath));
}

class P3p extends P3pgo {
  P3p(super.dynamicLibrary);

  void initStore(String path) => InitStore(path.toNativeUtf8().cast<Char>());

  UserInfo getSelfInfo() => UserInfo(this, userInfoType.privateInfo, 0);

  UserInfo addUserFromPublicKey(String publicKey) {
    final publickeyRaw = publicKey.toNativeUtf8().cast<Char>();
    final uid = AddUserByPublicKey(publickeyRaw);
    calloc.free(publickeyRaw);
    return UserInfo(this, userInfoType.userInfo, uid);
  }

  Iterable<Message> getMessages(UserInfo userInfo) {
    final result = GetChatMessages(userInfo.id).cast<Utf8>().toDartString();
    print('result: $result');
    final idList = json.decode(result) as List<dynamic>;
    final mids = <Message>[];
    for (final mid in idList) {
      mids.add(Message(this, mid as int));
    }
    return mids;
  }

  void sendMessage(
    UserInfo userInfo,
    String text, {
    MessageType type = MessageType.text,
  }) =>
      SendMessage(userInfo.id, text.toNativeUtf8().cast<Char>());

  void print(dynamic s) {
    final log = '[p3p]: $s'.toNativeUtf8().cast<Char>();
    Print(log);
    calloc.free(log);
  }

  void updateFileContent(FileStoreElement updateElm) =>
      throw UnimplementedError();

  Iterable<FileStoreElement> getFileStoreElements(UserInfo chatroom) =>
      throw UnimplementedError();

  FileStoreElement putFileStoreElement(
    UserInfo chatroom, {
    required localFile,
    required localFileSha512sum,
    required int sizeBytes,
    required String fileInChatPath,
    required uuid,
    required bool shouldFetch,
  }) =>
      throw UnimplementedError();

  Iterable<UserInfo> getAllUserInfo() {
    final result = GetAllUserInfo().cast<Utf8>().toDartString();

    final idList = json.decode(result) as List<dynamic>;
    final uis = <UserInfo>[];
    for (final uid in idList) {
      uis.add(UserInfo(this, userInfoType.userInfo, uid as int));
    }
    return uis;
  }

  UserInfo createSelfInfo(String username, String email, int bitSize) {
    CreateSelfInfo(
      username.toNativeUtf8().cast<Char>(),
      email.toNativeUtf8().cast<Char>(),
      bitSize,
    );
    return UserInfo(this, userInfoType.privateInfo, 0);
  }

  bool showSetup() {
    final ret = ShowSetup();
    print('showSetup(): $ret');
    return ret == 1;
  }

  void setPrivateInfoEepsiteDomain(String eepsite) {
    SetPrivateInfoEepsiteDomain(eepsite.toNativeUtf8().cast<Char>());
  }
}

// TODO(mrcyjanek): Export any libraries intended for clients of this package.
