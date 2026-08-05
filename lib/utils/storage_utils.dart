import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppStorageInfo {
  final int isarSize;
  final int totalAppDataSize;

  const AppStorageInfo({
    required this.isarSize,
    required this.totalAppDataSize,
  });
}

Future<int> getFileSizeIfExists(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    return 0;
  }
  return file.length();
}

Future<int> getDirectorySize(Directory dir) async {
  if (!await dir.exists()) {
    return 0;
  }

  var total = 0;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      total += await entity.length();
    }
  }
  return total;
}

Future<AppStorageInfo> getAppStorageInfo() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  final isarSize = await getFileSizeIfExists(
    '${documentsDir.path}/default.isar',
  );
  final isarLockSize = await getFileSizeIfExists(
    '${documentsDir.path}/default.isar.lock',
  );
  final totalAppDataSize = await getDirectorySize(documentsDir);

  return AppStorageInfo(
    isarSize: isarSize + isarLockSize,
    totalAppDataSize: totalAppDataSize,
  );
}

String formatStorageSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
