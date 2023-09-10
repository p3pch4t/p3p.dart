import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:p3p/p3p.dart';
// ignore: unnecessary_import

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Filestore - p3p filesystem is defined here
/// Yes, I'm fully aware that you don't design filesystem
/// that high in the abstraction world but hey.. it works.

class FileStoreElement {
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

  int id = -1;
  String uuid = const Uuid().v4();
  // String get path => p.normalize(p.join('/', dbPath));
  // set path(String nPath) {
  //   dbPath = p.normalize(p.join('/', nPath));
  // }
  String path;
  String sha512sum;
  int sizeBytes;
  String localPath;
  bool isDeleted = false;
  DateTime modifyTime = DateTime.fromMicrosecondsSinceEpoch(0);
  int get downloadedSizeBytes => file.lengthSync();
  bool shouldFetch = false;
  File get file => File(localPath);
  String roomFingerprint;
  bool requestedLatestVersion = false;

  Future<void> saveAndBroadcast(P3p p3p) async {
    if ((p.basename(path).endsWith('xdc') ||
            p.basename(path).endsWith('.jsonp')) &&
        sizeBytes != await file.length()) {
      shouldFetch = true;
    }
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

  Future<void> updateContent(
    P3p p3p,
  ) async {
    print('updateContent');
    sizeBytes = downloadedSizeBytes;
    modifyTime = DateTime.now();
    sha512sum = calcSha512Sum(await file.readAsBytes());
    final useri = await p3p.db.getUserInfo(
      publicKey: await p3p.db.getPublicKey(fingerprint: roomFingerprint),
    );
    if (useri == null) print('useri == null - not announcing update.');
    await useri?.addEvent(
      p3p,
      Event(
        eventType: EventType.fileMetadata,
        data: EventFileMetadata(files: [this]),
      ),
    );
    await p3p.db.save(this);
  }

  static String calcSha512Sum(Uint8List bytes) {
    return crypto.sha512.convert(bytes).toString();
  }

  static FileStoreElement fromJson(Map<String, dynamic> body) {
    return FileStoreElement(
      sha512sum: body['sha512sum'] as String,
      sizeBytes: body['sizeBytes'] as int,
      localPath: '',
      roomFingerprint: '',
      path: body['path'] as String,
    )
      ..uuid = body['uuid'] as String
      ..modifyTime =
          DateTime.fromMicrosecondsSinceEpoch(body['modifyTime'] as int);
  }

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

class FileStore {
  FileStore({
    required this.roomFingerprint,
  });
  String roomFingerprint;

  Future<List<FileStoreElement>> getFileStoreElement(P3p p3p) async {
    return await p3p.db.getFileStoreElementList(
      roomFingerprint: roomFingerprint,
      deleted: false,
    );
  }

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
        print('invalid file size.');
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
    print('filestore: useri: $useri');
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
