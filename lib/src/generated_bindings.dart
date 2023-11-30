// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
// ignore_for_file: type=lint
import 'dart:ffi' as ffi;

/// Bindings to p3p golang api
class P3pgo {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  P3pgo(ffi.DynamicLibrary dynamicLibrary) : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  P3pgo.fromLookup(
      ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
          lookup)
      : _lookup = lookup;

  void Print(
    ffi.Pointer<ffi.Char> s,
  ) {
    return _Print(
      s,
    );
  }

  late final _PrintPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>>(
          'Print');
  late final _Print =
      _PrintPtr.asFunction<void Function(ffi.Pointer<ffi.Char>)>();

  int HealthCheck() {
    return _HealthCheck();
  }

  late final _HealthCheckPtr =
      _lookup<ffi.NativeFunction<GoUint8 Function()>>('HealthCheck');
  late final _HealthCheck = _HealthCheckPtr.asFunction<int Function()>();

  int OpenPrivateInfo(
    ffi.Pointer<ffi.Char> storePath,
    ffi.Pointer<ffi.Char> accountName,
  ) {
    return _OpenPrivateInfo(
      storePath,
      accountName,
    );
  }

  late final _OpenPrivateInfoPtr = _lookup<
      ffi.NativeFunction<
          GoInt Function(ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>)>>('OpenPrivateInfo');
  late final _OpenPrivateInfo = _OpenPrivateInfoPtr.asFunction<
      int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)>();

  int ShowSetup(
    int piId,
  ) {
    return _ShowSetup(
      piId,
    );
  }

  late final _ShowSetupPtr =
      _lookup<ffi.NativeFunction<GoUint8 Function(GoInt)>>('ShowSetup');
  late final _ShowSetup = _ShowSetupPtr.asFunction<int Function(int)>();

  int CreateSelfInfo(
    int piId,
    ffi.Pointer<ffi.Char> username,
    ffi.Pointer<ffi.Char> email,
    int bitSize,
  ) {
    return _CreateSelfInfo(
      piId,
      username,
      email,
      bitSize,
    );
  }

  late final _CreateSelfInfoPtr = _lookup<
      ffi.NativeFunction<
          GoUint8 Function(GoInt, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>,
              GoInt)>>('CreateSelfInfo');
  late final _CreateSelfInfo = _CreateSelfInfoPtr.asFunction<
      int Function(int, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>, int)>();

  ffi.Pointer<ffi.Char> GetAllUserInfo(
    int piId,
  ) {
    return _GetAllUserInfo(
      piId,
    );
  }

  late final _GetAllUserInfoPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt)>>(
          'GetAllUserInfo');
  late final _GetAllUserInfo =
      _GetAllUserInfoPtr.asFunction<ffi.Pointer<ffi.Char> Function(int)>();

  int AddUserByPublicKey(
    int piId,
    ffi.Pointer<ffi.Char> publickey,
    ffi.Pointer<ffi.Char> username,
    ffi.Pointer<ffi.Char> endpoint,
  ) {
    return _AddUserByPublicKey(
      piId,
      publickey,
      username,
      endpoint,
    );
  }

  late final _AddUserByPublicKeyPtr = _lookup<
      ffi.NativeFunction<
          GoInt Function(GoInt, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>)>>('AddUserByPublicKey');
  late final _AddUserByPublicKey = _AddUserByPublicKeyPtr.asFunction<
      int Function(int, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>,
          ffi.Pointer<ffi.Char>)>();

  int ForceSendIntroduceEvent(
    int piId,
    int uid,
  ) {
    return _ForceSendIntroduceEvent(
      piId,
      uid,
    );
  }

  late final _ForceSendIntroduceEventPtr =
      _lookup<ffi.NativeFunction<GoUint8 Function(GoInt, GoInt)>>(
          'ForceSendIntroduceEvent');
  late final _ForceSendIntroduceEvent =
      _ForceSendIntroduceEventPtr.asFunction<int Function(int, int)>();

  ffi.Pointer<ffi.Char> GetUserDetailsByURL(
    ffi.Pointer<ffi.Char> url,
  ) {
    return _GetUserDetailsByURL(
      url,
    );
  }

  late final _GetUserDetailsByURLPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi.Char> Function(
              ffi.Pointer<ffi.Char>)>>('GetUserDetailsByURL');
  late final _GetUserDetailsByURL = _GetUserDetailsByURLPtr.asFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>();

  ffi.Pointer<ffi.Char> GetUserInfoMessages(
    int piId,
    int UserInfoID,
  ) {
    return _GetUserInfoMessages(
      piId,
      UserInfoID,
    );
  }

  late final _GetUserInfoMessagesPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt, GoInt)>>(
          'GetUserInfoMessages');
  late final _GetUserInfoMessages = _GetUserInfoMessagesPtr.asFunction<
      ffi.Pointer<ffi.Char> Function(int, int)>();

  ffi.Pointer<ffi.Char> GetMessageType(
    int piId,
    int msgID,
  ) {
    return _GetMessageType(
      piId,
      msgID,
    );
  }

  late final _GetMessageTypePtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt, GoInt)>>(
          'GetMessageType');
  late final _GetMessageType =
      _GetMessageTypePtr.asFunction<ffi.Pointer<ffi.Char> Function(int, int)>();

  ffi.Pointer<ffi.Char> GetMessageText(
    int piId,
    int msgID,
  ) {
    return _GetMessageText(
      piId,
      msgID,
    );
  }

  late final _GetMessageTextPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt, GoInt)>>(
          'GetMessageText');
  late final _GetMessageText =
      _GetMessageTextPtr.asFunction<ffi.Pointer<ffi.Char> Function(int, int)>();

  int GetMessageReceivedTimestamp(
    int piId,
    int msgID,
  ) {
    return _GetMessageReceivedTimestamp(
      piId,
      msgID,
    );
  }

  late final _GetMessageReceivedTimestampPtr =
      _lookup<ffi.NativeFunction<GoInt64 Function(GoInt, GoInt)>>(
          'GetMessageReceivedTimestamp');
  late final _GetMessageReceivedTimestamp =
      _GetMessageReceivedTimestampPtr.asFunction<int Function(int, int)>();

  int GetMessageIsIncoming(
    int piId,
    int msgID,
  ) {
    return _GetMessageIsIncoming(
      piId,
      msgID,
    );
  }

  late final _GetMessageIsIncomingPtr =
      _lookup<ffi.NativeFunction<GoUint8 Function(GoInt, GoInt)>>(
          'GetMessageIsIncoming');
  late final _GetMessageIsIncoming =
      _GetMessageIsIncomingPtr.asFunction<int Function(int, int)>();

  int GetUserInfoId(
    int piId,
    int uid,
  ) {
    return _GetUserInfoId(
      piId,
      uid,
    );
  }

  late final _GetUserInfoIdPtr =
      _lookup<ffi.NativeFunction<GoInt64 Function(GoInt, GoInt)>>(
          'GetUserInfoId');
  late final _GetUserInfoId =
      _GetUserInfoIdPtr.asFunction<int Function(int, int)>();

  int GetPrivateInfoId(
    int piId,
  ) {
    return _GetPrivateInfoId(
      piId,
    );
  }

  late final _GetPrivateInfoIdPtr =
      _lookup<ffi.NativeFunction<GoInt64 Function(GoInt)>>('GetPrivateInfoId');
  late final _GetPrivateInfoId =
      _GetPrivateInfoIdPtr.asFunction<int Function(int)>();

  ffi.Pointer<ffi.Char> GetUserInfoPublicKeyArmored(
    int piId,
    int uid,
  ) {
    return _GetUserInfoPublicKeyArmored(
      piId,
      uid,
    );
  }

  late final _GetUserInfoPublicKeyArmoredPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt, GoInt)>>(
          'GetUserInfoPublicKeyArmored');
  late final _GetUserInfoPublicKeyArmored = _GetUserInfoPublicKeyArmoredPtr
      .asFunction<ffi.Pointer<ffi.Char> Function(int, int)>();

  ffi.Pointer<ffi.Char> GetPrivateInfoPublicKeyArmored(
    int piId,
  ) {
    return _GetPrivateInfoPublicKeyArmored(
      piId,
    );
  }

  late final _GetPrivateInfoPublicKeyArmoredPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt)>>(
          'GetPrivateInfoPublicKeyArmored');
  late final _GetPrivateInfoPublicKeyArmored =
      _GetPrivateInfoPublicKeyArmoredPtr.asFunction<
          ffi.Pointer<ffi.Char> Function(int)>();

  ffi.Pointer<ffi.Char> GetUserInfoUsername(
    int piId,
    int uid,
  ) {
    return _GetUserInfoUsername(
      piId,
      uid,
    );
  }

  late final _GetUserInfoUsernamePtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt, GoInt)>>(
          'GetUserInfoUsername');
  late final _GetUserInfoUsername = _GetUserInfoUsernamePtr.asFunction<
      ffi.Pointer<ffi.Char> Function(int, int)>();

  ffi.Pointer<ffi.Char> GetPrivateInfoUsername(
    int piId,
  ) {
    return _GetPrivateInfoUsername(
      piId,
    );
  }

  late final _GetPrivateInfoUsernamePtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt)>>(
          'GetPrivateInfoUsername');
  late final _GetPrivateInfoUsername = _GetPrivateInfoUsernamePtr.asFunction<
      ffi.Pointer<ffi.Char> Function(int)>();

  void SetUserInfoUsername(
    int piId,
    int uid,
    ffi.Pointer<ffi.Char> username,
  ) {
    return _SetUserInfoUsername(
      piId,
      uid,
      username,
    );
  }

  late final _SetUserInfoUsernamePtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
              GoInt, GoInt, ffi.Pointer<ffi.Char>)>>('SetUserInfoUsername');
  late final _SetUserInfoUsername = _SetUserInfoUsernamePtr.asFunction<
      void Function(int, int, ffi.Pointer<ffi.Char>)>();

  void SetPrivateInfoUsername(
    int piId,
    ffi.Pointer<ffi.Char> username,
  ) {
    return _SetPrivateInfoUsername(
      piId,
      username,
    );
  }

  late final _SetPrivateInfoUsernamePtr = _lookup<
          ffi.NativeFunction<ffi.Void Function(GoInt, ffi.Pointer<ffi.Char>)>>(
      'SetPrivateInfoUsername');
  late final _SetPrivateInfoUsername = _SetPrivateInfoUsernamePtr.asFunction<
      void Function(int, ffi.Pointer<ffi.Char>)>();

  void SetPrivateInfoEepsiteDomain(
    int piId,
    ffi.Pointer<ffi.Char> eepsite,
  ) {
    return _SetPrivateInfoEepsiteDomain(
      piId,
      eepsite,
    );
  }

  late final _SetPrivateInfoEepsiteDomainPtr = _lookup<
          ffi.NativeFunction<ffi.Void Function(GoInt, ffi.Pointer<ffi.Char>)>>(
      'SetPrivateInfoEepsiteDomain');
  late final _SetPrivateInfoEepsiteDomain = _SetPrivateInfoEepsiteDomainPtr
      .asFunction<void Function(int, ffi.Pointer<ffi.Char>)>();

  ffi.Pointer<ffi.Char> GetUserInfoEndpoint(
    int piId,
    int uid,
  ) {
    return _GetUserInfoEndpoint(
      piId,
      uid,
    );
  }

  late final _GetUserInfoEndpointPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt, GoInt)>>(
          'GetUserInfoEndpoint');
  late final _GetUserInfoEndpoint = _GetUserInfoEndpointPtr.asFunction<
      ffi.Pointer<ffi.Char> Function(int, int)>();

  void SetUserInfoEndpoint(
    int piId,
    int uid,
    ffi.Pointer<ffi.Char> endpoint,
  ) {
    return _SetUserInfoEndpoint(
      piId,
      uid,
      endpoint,
    );
  }

  late final _SetUserInfoEndpointPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
              GoInt, GoInt, ffi.Pointer<ffi.Char>)>>('SetUserInfoEndpoint');
  late final _SetUserInfoEndpoint = _SetUserInfoEndpointPtr.asFunction<
      void Function(int, int, ffi.Pointer<ffi.Char>)>();

  ffi.Pointer<ffi.Char> GetPrivateInfoEndpoint(
    int piId,
  ) {
    return _GetPrivateInfoEndpoint(
      piId,
    );
  }

  late final _GetPrivateInfoEndpointPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt)>>(
          'GetPrivateInfoEndpoint');
  late final _GetPrivateInfoEndpoint = _GetPrivateInfoEndpointPtr.asFunction<
      ffi.Pointer<ffi.Char> Function(int)>();

  void SetPrivateInfoEndpoint(
    int piId,
    ffi.Pointer<ffi.Char> endpoint,
  ) {
    return _SetPrivateInfoEndpoint(
      piId,
      endpoint,
    );
  }

  late final _SetPrivateInfoEndpointPtr = _lookup<
          ffi.NativeFunction<ffi.Void Function(GoInt, ffi.Pointer<ffi.Char>)>>(
      'SetPrivateInfoEndpoint');
  late final _SetPrivateInfoEndpoint = _SetPrivateInfoEndpointPtr.asFunction<
      void Function(int, ffi.Pointer<ffi.Char>)>();

  ffi.Pointer<ffi.Char> GetPublicKeyFingerprint(
    ffi.Pointer<ffi.Char> armored,
  ) {
    return _GetPublicKeyFingerprint(
      armored,
    );
  }

  late final _GetPublicKeyFingerprintPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<ffi.Char> Function(
              ffi.Pointer<ffi.Char>)>>('GetPublicKeyFingerprint');
  late final _GetPublicKeyFingerprint = _GetPublicKeyFingerprintPtr.asFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>();

  void SendMessage(
    int piId,
    int uid,
    ffi.Pointer<ffi.Char> text,
  ) {
    return _SendMessage(
      piId,
      uid,
      text,
    );
  }

  late final _SendMessagePtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
              GoInt, GoInt64, ffi.Pointer<ffi.Char>)>>('SendMessage');
  late final _SendMessage = _SendMessagePtr.asFunction<
      void Function(int, int, ffi.Pointer<ffi.Char>)>();

  int CreateFileStoreElement(
    int piId,
    int uid,
    ffi.Pointer<ffi.Char> fileInChatPath,
    ffi.Pointer<ffi.Char> localFilePath,
  ) {
    return _CreateFileStoreElement(
      piId,
      uid,
      fileInChatPath,
      localFilePath,
    );
  }

  late final _CreateFileStoreElementPtr = _lookup<
      ffi.NativeFunction<
          GoInt64 Function(GoInt, GoUint, ffi.Pointer<ffi.Char>,
              ffi.Pointer<ffi.Char>)>>('CreateFileStoreElement');
  late final _CreateFileStoreElement = _CreateFileStoreElementPtr.asFunction<
      int Function(int, int, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>)>();

  ffi.Pointer<ffi.Char> GetFileStoreElementLocalPath(
    int piId,
    int fseId,
  ) {
    return _GetFileStoreElementLocalPath(
      piId,
      fseId,
    );
  }

  late final _GetFileStoreElementLocalPathPtr = _lookup<
          ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt, GoUint)>>(
      'GetFileStoreElementLocalPath');
  late final _GetFileStoreElementLocalPath = _GetFileStoreElementLocalPathPtr
      .asFunction<ffi.Pointer<ffi.Char> Function(int, int)>();

  int GetFileStoreElementIsDownloaded(
    int piId,
    int fseId,
  ) {
    return _GetFileStoreElementIsDownloaded(
      piId,
      fseId,
    );
  }

  late final _GetFileStoreElementIsDownloadedPtr =
      _lookup<ffi.NativeFunction<GoUint8 Function(GoInt, GoUint)>>(
          'GetFileStoreElementIsDownloaded');
  late final _GetFileStoreElementIsDownloaded =
      _GetFileStoreElementIsDownloadedPtr.asFunction<int Function(int, int)>();

  int GetFileStoreElementSizeBytes(
    int piId,
    int fseId,
  ) {
    return _GetFileStoreElementSizeBytes(
      piId,
      fseId,
    );
  }

  late final _GetFileStoreElementSizeBytesPtr =
      _lookup<ffi.NativeFunction<GoInt64 Function(GoInt, GoUint)>>(
          'GetFileStoreElementSizeBytes');
  late final _GetFileStoreElementSizeBytes =
      _GetFileStoreElementSizeBytesPtr.asFunction<int Function(int, int)>();

  ffi.Pointer<ffi.Char> GetFileStoreElementPath(
    int piId,
    int fseId,
  ) {
    return _GetFileStoreElementPath(
      piId,
      fseId,
    );
  }

  late final _GetFileStoreElementPathPtr = _lookup<
          ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt, GoUint)>>(
      'GetFileStoreElementPath');
  late final _GetFileStoreElementPath = _GetFileStoreElementPathPtr.asFunction<
      ffi.Pointer<ffi.Char> Function(int, int)>();

  void SetFileStoreElementPath(
    int piId,
    int fseId,
    ffi.Pointer<ffi.Char> newPath,
  ) {
    return _SetFileStoreElementPath(
      piId,
      fseId,
      newPath,
    );
  }

  late final _SetFileStoreElementPathPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(GoInt, GoUint,
              ffi.Pointer<ffi.Char>)>>('SetFileStoreElementPath');
  late final _SetFileStoreElementPath = _SetFileStoreElementPathPtr.asFunction<
      void Function(int, int, ffi.Pointer<ffi.Char>)>();

  int GetFileStoreElementIsDeleted(
    int piId,
    int fseId,
  ) {
    return _GetFileStoreElementIsDeleted(
      piId,
      fseId,
    );
  }

  late final _GetFileStoreElementIsDeletedPtr =
      _lookup<ffi.NativeFunction<GoUint8 Function(GoInt, GoUint)>>(
          'GetFileStoreElementIsDeleted');
  late final _GetFileStoreElementIsDeleted =
      _GetFileStoreElementIsDeletedPtr.asFunction<int Function(int, int)>();

  void SetFileStoreElementIsDeleted(
    int piId,
    int fseId,
    int isDeleted,
  ) {
    return _SetFileStoreElementIsDeleted(
      piId,
      fseId,
      isDeleted,
    );
  }

  late final _SetFileStoreElementIsDeletedPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(GoInt, GoUint, GoUint8)>>(
          'SetFileStoreElementIsDeleted');
  late final _SetFileStoreElementIsDeleted = _SetFileStoreElementIsDeletedPtr
      .asFunction<void Function(int, int, int)>();

  ffi.Pointer<ffi.Char> GetUserInfoFileStoreElements(
    int piId,
    int UserInfoID,
  ) {
    return _GetUserInfoFileStoreElements(
      piId,
      UserInfoID,
    );
  }

  late final _GetUserInfoFileStoreElementsPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(GoInt, GoInt)>>(
          'GetUserInfoFileStoreElements');
  late final _GetUserInfoFileStoreElements = _GetUserInfoFileStoreElementsPtr
      .asFunction<ffi.Pointer<ffi.Char> Function(int, int)>();
}

final class max_align_t extends ffi.Opaque {}

final class _GoString_ extends ffi.Struct {
  external ffi.Pointer<ffi.Char> p;

  @ptrdiff_t()
  external int n;
}

typedef ptrdiff_t = ffi.Long;

final class GoInterface extends ffi.Struct {
  external ffi.Pointer<ffi.Void> t;

  external ffi.Pointer<ffi.Void> v;
}

final class GoSlice extends ffi.Struct {
  external ffi.Pointer<ffi.Void> data;

  @GoInt()
  external int len;

  @GoInt()
  external int cap;
}

typedef GoInt = GoInt64;
typedef GoInt64 = ffi.LongLong;
typedef GoUint8 = ffi.UnsignedChar;
typedef GoUint = GoUint64;
typedef GoUint64 = ffi.UnsignedLongLong;

const int NULL = 0;
