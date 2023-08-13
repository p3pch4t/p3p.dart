import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:p3p/src/userinfo.dart';
import 'package:uuid/uuid.dart';

import 'package:path/path.dart' as p;

part 'filestore.g.dart';

/// Filestore - p3p filesystem is defined here
/// Yes, I'm fully aware that you don't design filesystem
/// that high in the abstraction world but hey.. it works.

@HiveType(typeId: 7)
class FileStoreElement {
  FileStoreElement({
    required this.rawPath,
    required this.sha512sum,
    required this.sizeBytes,
    required this.downloadedSizeBytes,
    required this.localPath,
  });

  @HiveField(0)
  String uuid = Uuid().v4();

  @HiveField(1)
  String rawPath;

  String get path => p.normalize(p.join('/', rawPath));
  set path(String nPath) {
    rawPath = p.normalize(p.join('/', nPath));
  }

  @HiveField(2)
  String sha512sum;

  @HiveField(3)
  int sizeBytes;

  @HiveField(4)
  String localPath;

  @HiveField(5)
  bool isDeleted = false;

  @HiveField(6)
  DateTime modifyTime = DateTime.fromMicrosecondsSinceEpoch(0);

  @HiveField(7)
  int downloadedSizeBytes;

  @HiveField(8, defaultValue: false)
  bool shouldFetch = false;

  File get file => File(localPath);

  Future<void> save(LazyBox<FileStoreElement> filestoreelementBox,
      LazyBox<UserInfo> userinfoBox, String roomId,
      {bool noUpdate = false}) async {
    modifyTime = DateTime.now();
    if (!noUpdate) {
      final useri = await userinfoBox.get(roomId);
      print("useri: ${useri?.publicKey.fingerprint}/$roomId");
      if (useri != null) {
        useri.lastIntroduce = DateTime(2000);
        print("lasti:${useri.lastIntroduce}");
        await userinfoBox.put(roomId, useri);
      }
    }
    await filestoreelementBox.put("$roomId.$uuid", this);
  }

  Future<void> updateContent(
    LazyBox<FileStoreElement> filestoreelementBox,
    LazyBox<UserInfo> userinfoBox,
    String roomId,
  ) async {
    downloadedSizeBytes = await file.length();
    sizeBytes = downloadedSizeBytes;
    sha512sum = calcSha512Sum(await file.readAsBytes());

    await save(filestoreelementBox, userinfoBox, roomId);
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
    required this.roomId,
  });
  String roomId;

  Future<List<FileStoreElement>> getFileStoreElement(
    LazyBox<FileStoreElement> filestoreelementBox,
  ) async {
    final ret = <FileStoreElement>[];
    for (String key in filestoreelementBox.keys) {
      if (!key.startsWith(roomId)) continue; // not part of this filestore
      final fee = await filestoreelementBox.get(key);
      if (fee == null) continue;
      ret.add(fee);
    }
    return ret;
  }

  Future<FileStoreElement> putFileStoreElement(
      LazyBox<FileStoreElement> filestoreelementBox,
      LazyBox<UserInfo> userinfoBox,
      File? localFile,
      String? localFileSha512sum,
      int sizeBytes,
      String fileInChatPath,
      String fileStorePath,
      {String? uuid}) async {
    if (localFile != null && localFileSha512sum == null) {
      print(
        "you need to provide either or none localFile and localFileSha512sum",
      );
      throw Error();
    }
    final sha512sum = localFileSha512sum ??
        FileStoreElement.calcSha512Sum(
          localFile?.readAsBytesSync() ?? Uint8List(0),
        );
    final storeFile = File(p.join(fileStorePath, "$roomId-${Uuid().v4()}"));
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
    final fselm = FileStoreElement(
      rawPath: '/',
      sha512sum: sha512sum,
      sizeBytes: sizeBytes,
      downloadedSizeBytes: await storeFile.length(),
      localPath: storeFile.path,
    )
      ..shouldFetch = localFile == null ? false : true
      ..path = fileInChatPath;
    if (uuid != null) fselm.uuid = uuid;
    await filestoreelementBox.put("$roomId.${fselm.uuid}", fselm);
    final useri = await userinfoBox.get(roomId);
    if (useri == null) return fselm;
    useri.lastIntroduce = DateTime.fromMicrosecondsSinceEpoch(0);
    await userinfoBox.put(useri.publicKey.fingerprint, useri);
    return fselm;
  }
}
