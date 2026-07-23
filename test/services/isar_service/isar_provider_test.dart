import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';

import '../../test_helpers.dart';

void main() {
  late Directory tempDirectory;
  late IsarProvider isarProvider;
  late Isar isar;

  setUp(() async {
    initializeTestDependencies();
    tempDirectory = Directory.systemTemp.createTempSync();
    mockPathProvider(tempDirectory.path);
    isarProvider = IsarProvider();
    isar = await isarProvider.getDatabase();
    await clearIsarDatabase(isar);
  });

  tearDown(() async {
    await isarProvider.close();
  });

  group('IsarProvider.runWriteTxn', () {
    test('serializes concurrent writes without error', () async {
      final results = await Future.wait(List.generate(20, (index) {
        return isarProvider.runWriteTxn((isar) async {
          final track = TrackData()..isDirectUpload = 0;
          return isar.trackDatas.put(track);
        });
      }));

      expect(results.length, 20);
      expect(results.toSet().length, 20);

      final tracks = await isar.trackDatas.where().findAll();
      expect(tracks.length, 20);
    });
  });
}
