import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:p3p/p3p.dart';
import 'package:uuid/uuid.dart';

// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

import 'package:path/path.dart' as p;

/// Filestore - p3p filesystem is defined here
/// Yes, I'm fully aware that you don't design filesystem
/// that high in the abstraction world but hey.. it works.

@Entity()
class FileStoreElement {
  FileStoreElement({
    required this.dbPath,
    required this.sha512sum,
    required this.sizeBytes,
    required this.localPath,
    required this.roomFingerprint,
  });

  @Id()
  int id = 0;

  String uuid = Uuid().v4();

  String dbPath;

  @Transient()
  String get path => p.normalize(p.join('/', dbPath));
  @Transient()
  set path(String nPath) {
    dbPath = p.normalize(p.join('/', nPath));
  }

  String sha512sum;

  int sizeBytes;

  String localPath;

  bool isDeleted = false;

  @Property(type: PropertyType.date)
  DateTime modifyTime = DateTime.fromMillisecondsSinceEpoch(0);

  int get downloadedSizeBytes => file.lengthSync();

  bool shouldFetch = false;

  @Transient()
  File get file => File(localPath);

  @Index()
  String roomFingerprint;

  bool requestedLatestVersion = false;

  Future<void> save(P3p p3p, {bool shouldIntroduce = true}) async {
    if (shouldIntroduce) {
      modifyTime = DateTime.now();
      final useri = p3p.getUserInfo(roomFingerprint);
      if (useri != null) {
        useri.lastIntroduce = DateTime(2000);
        useri.save(p3p);
      }
    }
    if (p.basename(path).endsWith('xdc') ||
        p.basename(path).endsWith('.jsonp')) {
      shouldFetch = true;
    }
    p3p.fileStoreElementBox.put(this);
    p3p.callOnFileStoreElement(
      FileStore(roomFingerprint: roomFingerprint),
      this,
    );
  }

  Future<void> updateContent(
    P3p p3p,
  ) async {
    sizeBytes = downloadedSizeBytes;
    modifyTime = DateTime.now();
    sha512sum = calcSha512Sum(await file.readAsBytes());

    await save(p3p);
  }

  static String calcSha512Sum(Uint8List bytes) {
    return crypto.sha512.convert(bytes).toString();
  }

  Map<String, dynamic> toJson() {
    return {
      "uuid": uuid,
      "path": path,
      "sha512sum": sha512sum,
      "sizeBytes": sizeBytes,
      // downloadedSizeBytes is local only.
      "isDeleted": isDeleted,
      "modifyTime": modifyTime.microsecondsSinceEpoch,
    };
  }
}

class FileStore {
  FileStore({
    required this.roomFingerprint,
  });
  String roomFingerprint;

  Future<List<FileStoreElement>> getFileStoreElement(P3p p3p) async {
    return p3p.fileStoreElementBox
        .query(FileStoreElement_.roomFingerprint
            .equals(roomFingerprint)
            .and(FileStoreElement_.isDeleted.equals(false)))
        .build()
        .find();
  }

  Future<FileStoreElement> putFileStoreElement(
    P3p p3p, {
    String? uuid,
    required File? localFile,
    required String? localFileSha512sum,
    required int sizeBytes,
    required String fileInChatPath,
  }) async {
    uuid ??= Uuid().v4();
    final sha512sum = localFileSha512sum ??
        FileStoreElement.calcSha512Sum(
          localFile?.readAsBytesSync() ?? Uint8List(0),
        );
    final storeFile =
        File(p.join(p3p.fileStorePath, "$roomFingerprint-${Uuid().v4()}"));
    if (!await storeFile.exists()) {
      await storeFile.create(recursive: true);
    }
    if (localFile != null) {
      await localFile.copy(p.join(storeFile.path));
      if (await localFile.length() != sizeBytes) {
        print("invalid file size.");
        throw Error();
      }
    }

    var fselm = p3p.fileStoreElementBox
        .query(FileStoreElement_.uuid
            .equals(uuid)
            .and(FileStoreElement_.roomFingerprint.equals(roomFingerprint)))
        .build()
        .findFirst();
    fselm ??= FileStoreElement(
      dbPath: '/',
      /* replaced lated by ..path = ... */
      sha512sum: sha512sum,
      sizeBytes: sizeBytes,
      localPath: storeFile.path,
      roomFingerprint: roomFingerprint,
    )
      ..shouldFetch = localFile == null ? false : true
      ..path = fileInChatPath
      ..uuid = uuid;
    p3p.fileStoreElementBox.put(fselm);
    final useri = p3p.getUserInfo(roomFingerprint);
    if (useri == null) return fselm;
    useri.lastIntroduce = DateTime.fromMicrosecondsSinceEpoch(0);
    useri.save(p3p);
    return fselm;
  }
}
