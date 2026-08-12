import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/utils/storage_utils.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(() {
    initializeTestDependencies();
  });

  group('formatStorageSize', () {
    test('formats bytes', () {
      expect(formatStorageSize(512), '512 B');
    });

    test('formats kilobytes', () {
      expect(formatStorageSize(1536), '1.5 KB');
    });

    test('formats megabytes', () {
      expect(formatStorageSize(2 * 1024 * 1024), '2.0 MB');
    });

    test('formats gigabytes', () {
      expect(formatStorageSize(3 * 1024 * 1024 * 1024), '3.0 GB');
    });
  });

  group('getDirectorySize', () {
    test('returns zero for missing directory', () async {
      final size = await getDirectorySize(
        Directory('/tmp/non-existent-directory-${DateTime.now().millisecondsSinceEpoch}'),
      );

      expect(size, 0);
    });

    test('sums nested file sizes', () async {
      final tempDir = await Directory.systemTemp.createTemp('storage_utils_test');
      final nestedDir = Directory('${tempDir.path}/nested');
      await nestedDir.create(recursive: true);

      final firstFile = File('${tempDir.path}/first.txt');
      final secondFile = File('${nestedDir.path}/second.txt');
      await firstFile.writeAsString('12345');
      await secondFile.writeAsString('abc');

      final size = await getDirectorySize(tempDir);

      expect(size, 8);
      await tempDir.delete(recursive: true);
    });
  });

  group('getFileSizeIfExists', () {
    test('returns zero for missing file', () async {
      final size = await getFileSizeIfExists(
        '/tmp/non-existent-file-${DateTime.now().millisecondsSinceEpoch}.txt',
      );

      expect(size, 0);
    });

    test('returns file length when file exists', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/storage_utils_file_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await tempFile.writeAsString('hello');

      final size = await getFileSizeIfExists(tempFile.path);

      expect(size, 5);
      await tempFile.delete();
    });
  });

  group('getAppStorageInfo', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('storage_utils_test');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      });
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns isar and total app data sizes', () async {
      await File('${tempDir.path}/default.isar').writeAsString('12345');
      await File('${tempDir.path}/export.csv').writeAsString('abc');

      final info = await getAppStorageInfo();

      expect(info.isarSize, 5);
      expect(info.totalAppDataSize, 8);
    });
  });
}
