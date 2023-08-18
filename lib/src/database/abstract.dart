import 'package:p3p/p3p.dart';

abstract class Database {
  Future<void> save<T>(T elm);

  Future<List<UserInfo>> getAllUserInfo();

  Future<void> remove<T>(T elm);

  Future<FileStoreElement?> getFileStoreElement(
      {required String? roomFingerprint, required String? uuid,});

  Future<List<FileStoreElement>> getFileStoreElementList(
      {required String? roomFingerprint, required bool? deleted,});

  Future<PublicKey?> getPublicKey({required String fingerprint});

  // call ..init()
  Future<UserInfo?> getUserInfo({PublicKey? publicKey, String? fingerprint});

  Future<List<Event>> getEvents({required PublicKey? destinationPublicKey});

  Future<List<Message>> getMessageList({required String? roomFingerprint});

  Future<Message?> getMessage(
      {required String? uuid, required String? roomFingerprint,});

  Future<Message?> getLastMessage();
}
