/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:p3p/src/generated_bindings.dart';
import 'package:p3p/src/message.dart';
import 'package:p3p/src/queuedevent.dart';
import 'package:p3p/src/userinfo.dart';

export 'src/message.dart';
export 'src/userinfo.dart';

/// getP3pGo - start p3pgo library, and return it's object.
Future<P3p> getP3p(String libPath) async {
  return P3p(DynamicLibrary.open(libPath));
}

class P3p extends P3pgo {
  P3p(super.dynamicLibrary);

  int? _piId;
  int get piId {
    if (_piId == null) {
      throw UnimplementedError('Did you forget to call .initStore()?');
    }
    return _piId!;
  }

  void initStore(
    String path,
    String accountName,
    String endpointPath, {
    bool isMini = false,
  }) {
    final path_ = path.toNativeUtf8().cast<Char>();
    final accountName_ = accountName.toNativeUtf8().cast<Char>();
    final endpointPath_ = endpointPath.toNativeUtf8().cast<Char>();
    final isMini_ = isMini ? 1 : 0;
    _piId = OpenPrivateInfo(path_, accountName_, endpointPath_, isMini_);
    calloc.free(path_);
    calloc.free(accountName_);
    calloc.free(endpointPath_);
  }

  UserInfo getSelfInfo() => UserInfo(this, UserInfoType.privateInfo, 0);

  UserInfo addUserFromPublicKey(
    String publicKey,
    String name,
    String endpoint,
  ) {
    final publickeyRaw = publicKey.toNativeUtf8().cast<Char>();
    final nameRaw = name.toNativeUtf8().cast<Char>();
    final endpointRaw = endpoint.toNativeUtf8().cast<Char>();
    final uid = AddUserByPublicKey(piId, publickeyRaw, nameRaw, endpointRaw);
    calloc.free(publickeyRaw);
    calloc.free(nameRaw);
    calloc.free(endpointRaw);
    return UserInfo(this, UserInfoType.userInfo, uid);
  }

  DiscoveredUserInfo? getUserDetailsByURL(String url) {
    final urlRaw = url.toNativeUtf8().cast<Char>();
    final duiStr = GetUserDetailsByURL(urlRaw).cast<Utf8>().toDartString();
    calloc.free(urlRaw);
    final j = json.decode(duiStr) as Map<String, dynamic>?;
    if (j?['name'] == null) return null;
    return DiscoveredUserInfo(
      this,
      name: j!['name'] as String,
      bio: j['bio'] as String,
      publickey: j['publickey'] as String,
      endpoint: j['endpoint'] as String,
    );
  }

  Iterable<Message> getMessages(UserInfo userInfo) {
    final result =
        GetUserInfoMessages(piId, userInfo.id).cast<Utf8>().toDartString();
    final idList = json.decode(result) as List<dynamic>? ?? [];
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
  }) {
    final text_ = text.toNativeUtf8().cast<Char>();
    SendMessage(piId, userInfo.id, text_);
    calloc.free(text_);
  }

  void print(dynamic s) {
    final log = '[p3p]: $s'.toNativeUtf8().cast<Char>();
    Print(log);
    calloc.free(log);
  }

  void createSharedFile(
    UserInfo ui, {
    required String localFilePath,
    required String remoteFilePath,
  }) {
    final localFilePath_ = localFilePath.toNativeUtf8();
    final remoteFilePath_ = remoteFilePath.toNativeUtf8();

    CreateFile(piId, ui.id, localFilePath_.cast(), remoteFilePath_.cast());
    calloc.free(localFilePath_);
    calloc.free(remoteFilePath_);
  }

  Iterable<UserInfo> getAllUserInfo() {
    final result = GetAllUserInfo(piId).cast<Utf8>().toDartString();

    final idList = json.decode(result) as List<dynamic>? ?? [];
    final uis = <UserInfo>[];
    for (final uid in idList) {
      uis.add(UserInfo(this, UserInfoType.userInfo, uid as int));
    }
    return uis;
  }

  UserInfo createSelfInfo(String username, String email, int bitSize) {
    CreateSelfInfo(
      piId,
      username.toNativeUtf8().cast<Char>(),
      email.toNativeUtf8().cast<Char>(),
      bitSize,
    );
    return UserInfo(this, UserInfoType.privateInfo, 0);
  }

  List<QueuedEvent> getQueuedEvents() {
    final result = GetQueuedEventIDs(piId).cast<Utf8>().toDartString();
    final idList = json.decode(result) as List<dynamic>? ?? [];
    final qes = <QueuedEvent>[];
    for (final uid in idList) {
      qes.add(QueuedEvent(this, id: uid as int));
    }
    return qes;
  }

  bool showSetup() {
    final ret = ShowSetup(piId);
    print('showSetup(): $ret');
    return ret == 1;
  }

  void setPrivateInfoEepsiteDomain(String eepsite) {
    SetPrivateInfoEepsiteDomain(piId, eepsite.toNativeUtf8().cast<Char>());
  }
}

// TODO(mrcyjanek): Export any libraries intended for clients of this package.
