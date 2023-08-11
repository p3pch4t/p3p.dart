import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart' as crypto;

part 'filestore.g.dart';

/// Filestore - p3p filesystem is defined here
/// Yes, I'm fully aware that you don't design filesystem
/// that high in the abstraction world but hey.. it works.

@HiveType(typeId: 7)
class FileStoreElement {
  FileStoreElement({
    required this.uuid,
    required this.path,
    required this.sha512sum,
    required this.sizeBytes,
    required this.localPath,
  });

  @HiveField(0)
  String uuid;

  @HiveField(1)
  String path;

  @HiveField(2)
  String sha512sum;

  @HiveField(3)
  int sizeBytes;

  @HiveField(4)
  String localPath;

  File get file => File(localPath);

  static String calcSha512Sum(Uint8List bytes) {
    return crypto.sha512.convert(bytes).toString();
  }
}

class FileStore {
  FileStore({
    required this.roomId,
  });
  String roomId;

  Future<List<FileStoreElement>> getFileStore(
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
}
