import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:p3p/p3p.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Filestore - p3p filesystem is defined here
/// Yes, I'm fully aware that you don't design filesystem
/// that high in the abstraction world but hey.. it works.
class FileStoreElement {
  // ignore: public_member_api_docs
  FileStoreElement({
    required this.sha512sum,
    required this.sizeBytes,
    required this.localPath,
    required this.roomFingerprint,
    required this.path,
    this.requestedLatestVersion = false,
    this.shouldFetch = false,
    this.isDeleted = false,
  });

  /// Create FileStoreElement from a json object
  FileStoreElement.fromJson(Map<String, dynamic> body) {
    sha512sum = body['sha512sum'] as String;
    sizeBytes = body['sizeBytes'] as int;
    localPath = '';
    roomFingerprint = '';
    path = body['path'] as String;

    uuid = body['uuid'] as String;
    modifyTime = DateTime.fromMicrosecondsSinceEpoch(body['modifyTime'] as int);
  }

  /// id = -1 when we want to insert
  int id = -1;

  /// User's specyfic unique uuid
  String uuid = const Uuid().v4();
  // String get path => p.normalize(p.join('/', dbPath));
  // set path(String nPath) {
  //   dbPath = p.normalize(p.join('/', nPath));
  // }
  /// in-chat path of the file (including both directory and file name)
  late String path;

  /// sha512sum of the file
  late String sha512sum;

  /// size in bytes
  late int sizeBytes;

  /// where is the file stored locally
  late String localPath;

  /// is the file deleted?
  bool isDeleted = false;

  /// When did we last modify the file?
  DateTime modifyTime = DateTime.fromMicrosecondsSinceEpoch(0);

  /// how much of the file did we download to out disk?
  int get downloadedSizeBytes => file.lengthSync();

  /// Should we download the file?
  bool shouldFetch = false;

  /// File() object pointing to the file.
  File get file => File(localPath);

  /// What is the roomFingerprint that this file belongs to?
  late String roomFingerprint;

  /// Did we request to download latest version of this file?
  bool requestedLatestVersion = false;

  /// saves the file, and broadcast the change to each user.
  Future<void> saveAndBroadcast(P3p p3p) async {
    if ((p.basename(path).endsWith('xdc') ||
            p.basename(path).endsWith('.jsonp')) &&
        sizeBytes != await file.length()) {
      shouldFetch = true;
    }
    if (p3p.db.singularFileStore) {
      // send to all users, since we are singular
      for (final user in await p3p.db.getAllUserInfo()) {
        await user.addEvent(
          p3p,
          Event(
            eventType: EventType.fileMetadata,
            data: EventFileMetadata(files: [this]),
          ),
        );

        await p3p.db.save(this);
        p3p.callOnFileStoreElement(
          FileStore(roomFingerprint: roomFingerprint),
          this,
        );
      }
    } else {
      // send to one user
      final user = (await p3p.db.getUserInfo(fingerprint: roomFingerprint))!;
      await user.addEvent(
        p3p,
        Event(
          eventType: EventType.fileMetadata,
          data: EventFileMetadata(files: [this]),
        ),
      );

      await p3p.db.save(this);
      p3p.callOnFileStoreElement(
        FileStore(roomFingerprint: roomFingerprint),
        this,
      );
    }
  }

  /// update the content, without doing any network stuff.
  Future<void> updateContent(
    P3p p3p,
  ) async {
    p3p.print('updateContent');
    sizeBytes = downloadedSizeBytes;
    modifyTime = DateTime.now();
    sha512sum = calcSha512Sum(await file.readAsBytes());
    if (p3p.db.singularFileStore) {
      for (final useri in await p3p.db.getAllUserInfo()) {
        p3p.print('useri == null - not announcing update.');
        await useri.addEvent(
          p3p,
          Event(
            eventType: EventType.fileMetadata,
            data: EventFileMetadata(files: [this]),
          ),
        );
      }
    } else {
      final useri = await p3p.db.getUserInfo(
        publicKey: await p3p.db.getPublicKey(fingerprint: roomFingerprint),
      );
      if (useri == null) p3p.print('useri == null - not announcing update.');
      await useri?.addEvent(
        p3p,
        Event(
          eventType: EventType.fileMetadata,
          data: EventFileMetadata(files: [this]),
        ),
      );
    }
    await p3p.db.save(this);
  }

  /// calculate sha512sum of Uing8List
  static String calcSha512Sum(Uint8List bytes) {
    return crypto.sha512.convert(bytes).toString();
  }

  /// convert FileStoreElement to JSON
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'path': path,
      'sha512sum': sha512sum,
      'sizeBytes': sizeBytes,
      // downloadedSizeBytes is local only.
      'isDeleted': isDeleted,
      'modifyTime': modifyTime.microsecondsSinceEpoch,
    };
  }
}

/// FileStore element that serves as helper for getting ans setting
/// FileStoreElement
class FileStore {
  /// It is initialized by UserInfo
  FileStore({
    required this.roomFingerprint,
  });

  /// fingerprint of the room
  String roomFingerprint;

  /// get List<FileStoreElement>> for the given FileStore
  Future<List<FileStoreElement>> getFileStoreElement(P3p p3p) async {
    return p3p.db.getFileStoreElementList(
      roomFingerprint: roomFingerprint,
      deleted: false,
    );
  }

  /// Put a FileStoreElement and return it's newer version
  Future<FileStoreElement> putFileStoreElement(
    P3p p3p, {
    required File? localFile,
    required String? localFileSha512sum,
    required int sizeBytes,
    required String fileInChatPath,
    required String? uuid,
  }) async {
    uuid ??= const Uuid().v4();
    final sha512sum = localFileSha512sum ??
        FileStoreElement.calcSha512Sum(
          localFile?.readAsBytesSync() ?? Uint8List(0),
        );
    final storeFile = File(
      p.join(p3p.fileStorePath, '$roomFingerprint-${const Uuid().v4()}'),
    );
    if (!storeFile.existsSync()) {
      await storeFile.create(recursive: true);
    }
    if (localFile != null) {
      await localFile.copy(p.join(storeFile.path));
      if (await localFile.length() != sizeBytes) {
        p3p.print('invalid file size.');
        throw Error();
      }
    }

    var fselm = await p3p.db.getFileStoreElement(
      roomFingerprint: roomFingerprint,
      uuid: uuid,
    );
    fselm ??= FileStoreElement(
      path: '/',
      /* replaced lated by ..path = ... */
      sha512sum: sha512sum,
      sizeBytes: sizeBytes,
      localPath: storeFile.path,
      roomFingerprint: roomFingerprint,
    )
      // ignore: avoid_bool_literals_in_conditional_expressions
      ..shouldFetch = (localFile == null ? false : true) ||
          (fileInChatPath.endsWith('.xdc') ||
              fileInChatPath.endsWith('.jsonp') ||
              fileInChatPath.startsWith('/.config') ||
              fileInChatPath.startsWith('.config'))
      ..path = fileInChatPath
      ..uuid = uuid;
    await p3p.db.save(fselm);
    final useri = await p3p.db.getUserInfo(
      publicKey: await p3p.db.getPublicKey(fingerprint: roomFingerprint),
    );
    p3p.print('filestore: useri: $useri');
    if (useri == null) return fselm;
    await useri.addEvent(
      p3p,
      Event(
        eventType: EventType.fileMetadata,
        data: EventFileMetadata(files: [fselm]),
      ),
    );
    await p3p.db.save(useri);
    return fselm;
  }
}
