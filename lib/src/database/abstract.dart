import 'package:p3p/p3p.dart';

/// Abstract class that is used to store all the objects used by p3pch4t
abstract class Database {
  /// One filestore for all users.
  /// This is used in ssmdc, where we take care of Event manually, and can
  /// deny write access to certain users.
  /// You most likely do not want a singularFileStore, unless you are
  /// writing some kind of bot that may benefit from this kind of feature.
  final bool singularFileStore = false;

  /// Save *any* object used in p3p.dart to database
  Future<int> save<T>(T elm);

  /// get information about all users, sorted by lastMessage
  Future<List<UserInfo>> getAllUserInfo();

  /// Remove *any* object used in p3p.dart to database
  Future<void> remove<T>(T elm);

  /// get FileStoreElement? by using either
  ///  - roomFingerprint or
  ///  - uuid
  Future<FileStoreElement?> getFileStoreElement({
    required String? roomFingerprint,
    required String? uuid,
  });

  /// get List<FileStoreElement>> by using
  ///  - roomFingerprint
  ///  - deleted (should we show deleted files)
  Future<List<FileStoreElement>> getFileStoreElementList({
    required String roomFingerprint,
    required bool deleted,
  });

  /// Get the publickey based on fingerprint
  Future<PublicKey?> getPublicKey({required String fingerprint});

  /// get UserInfo based on either a
  ///  - full p3p.PublicKey
  ///  -  fingerprint
  Future<UserInfo?> getUserInfo({PublicKey? publicKey, String? fingerprint});

  /// get all List<Event> for given PublicKey
  Future<List<Event>> getEvents({required PublicKey destinationPublicKey});

  /// get List<Message> based on a roomFingerprint
  Future<List<Message>> getMessageList({required String roomFingerprint});

  /// get Message based on either
  Future<Message?> getMessage({
    required String uuid,
    required String roomFingerprint,
  });

  /// get Message that was sent last
  Future<Message?> getLastMessage();
}
