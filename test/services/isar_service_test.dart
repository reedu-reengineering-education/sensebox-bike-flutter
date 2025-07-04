import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';

import '../mocks.dart';
import '../test_helpers.dart';


void main() {
  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/path_provider');

  late Isar isar;
  late IsarService isarService;
  late TrackData trackData;
  late GeolocationData geolocationData;
  late SensorData sensorData;
  late Directory tempDirectory;

  setUp(() async {
    initializeTestDependencies();

    // Create a temporary directory for testing
    tempDirectory = Directory.systemTemp.createTempSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDirectory.path;
      }
      return null;
    });

    isar = await initializeInMemoryIsar();
    // Mock IsarProvider to return the in-memory Isar instance
    final mockIsarProvider = MockIsarProvider();
    when(() => mockIsarProvider.getDatabase()).thenAnswer((_) async => isar);

    isarService = IsarService(isarProvider: mockIsarProvider);

    await clearIsarDatabase(isar);

    trackData = createMockTrackData();
    await isar.writeTxn(() async {
      await isar.trackDatas.put(trackData);
    });

    geolocationData = createMockGeolocationData(trackData);
    await isar.writeTxn(() async {
      await isar.geolocationDatas.put(geolocationData);
      await geolocationData.track.save();
    });

    sensorData = createMockSensorData(geolocationData);
    await isar.writeTxn(() async {
      await isar.sensorDatas.put(sensorData);
      await sensorData.geolocationData.save();
    });

    mockSenseBoxInSharedPreferences();
  });

  tearDown(() async {
    await isar.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('IsarService', () {
    group('deleteAllData', () {
      test('successfully deletes all data from the database', () async {
        final tracksBefore = await isar.trackDatas.where().findAll();
        final geolocationsBefore = await isar.geolocationDatas.where().findAll();
        final sensorsBefore = await isar.sensorDatas.where().findAll();

        expect(tracksBefore.length, equals(1));
        expect(geolocationsBefore.length, equals(1));
        expect(sensorsBefore.length, equals(1));
        await isarService.deleteAllData();


        final tracksAfter = await isar.trackDatas.where().findAll();
        final geolocationsAfter = await isar.geolocationDatas.where().findAll();
        final sensorsAfter = await isar.sensorDatas.where().findAll();

        expect(tracksAfter.isEmpty, isTrue);
        expect(geolocationsAfter.isEmpty, isTrue);
        expect(sensorsAfter.isEmpty, isTrue);
      });

      test('handles empty database gracefully', () async {
        await isarService.deleteAllData();

        // Act: Delete all data when the database is already empty
        await isarService.deleteAllData();

        final tracksAfter = await isar.trackDatas.where().findAll();
        final geolocationsAfter = await isar.geolocationDatas.where().findAll();
        final sensorsAfter = await isar.sensorDatas.where().findAll();

        expect(tracksAfter.isEmpty, isTrue);
        expect(geolocationsAfter.isEmpty, isTrue);
        expect(sensorsAfter.isEmpty, isTrue);
      });

      test('deletes multiple records from the database', () async {
        final trackData2 = TrackData();
        final geolocationData2 = GeolocationData()
          ..latitude = 48.8566
          ..longitude = 2.3522
          ..timestamp = DateTime.now().toUtc()
          ..speed = 10.0
          ..track.value = trackData2;

        final sensorData2 = SensorData()
          ..title = 'humidity'
          ..value = 60.0
          ..attribute = 'Percentage'
          ..characteristicUuid = '5678-1234-9012-3456'
          ..geolocationData.value = geolocationData2;

        await isar.writeTxn(() async {
          await isar.trackDatas.put(trackData2);
          await isar.geolocationDatas.put(geolocationData2);
          await geolocationData2.track.save();
          await isar.sensorDatas.put(sensorData2);
          await sensorData2.geolocationData.save();
        });


        final tracksBefore = await isar.trackDatas.where().findAll();
        final geolocationsBefore = await isar.geolocationDatas.where().findAll();
        final sensorsBefore = await isar.sensorDatas.where().findAll();
        expect(tracksBefore.length, equals(2));
        expect(geolocationsBefore.length, equals(2));
        expect(sensorsBefore.length, equals(2));

        await isarService.deleteAllData();

        final tracksAfter = await isar.trackDatas.where().findAll();
        final geolocationsAfter = await isar.geolocationDatas.where().findAll();
        final sensorsAfter = await isar.sensorDatas.where().findAll();
        expect(tracksAfter.isEmpty, isTrue);
        expect(geolocationsAfter.isEmpty, isTrue);
        expect(sensorsAfter.isEmpty, isTrue);
      });
    });
  });

  group('exportTrackToCsv', () {
    test('exports track data to CSV format', () async {
      final csvFilePath = await isarService.exportTrackToCsv(trackData.id);

      final file = File(csvFilePath);
      expect(file.existsSync(), isTrue);

      final csvContent = await file.readAsString();
      expect(csvContent.isNotEmpty, isTrue);
      expect(csvContent.contains('temperature'), isTrue);
    });

    test('throws an exception if the track has no geolocations', () async {
      final emptyTrack = TrackData();
      await isar.writeTxn(() async {
        await isar.trackDatas.put(emptyTrack);
      });

      expect(
        () async => await isarService.exportTrackToCsv(emptyTrack.id),
        throwsException,
      );
    });
  });

  group('exportTrackToCsvInOpenSenseMapFormat', () {
    test('exports track data to OpenSenseMap CSV format', () async {
      final csvFilePath =
          await isarService.exportTrackToCsvInOpenSenseMapFormat(trackData.id);

      final file = File(csvFilePath);
      expect(file.existsSync(), isTrue);

      final csvContent = await file.readAsString();
      expect(csvContent.isNotEmpty, isTrue);
      //expect(csvContent.contains('temperature'), isTrue);
    });

    test('throws an exception if the track has no geolocations', () async {
      final emptyTrack = TrackData();
      await isar.writeTxn(() async {
        await isar.trackDatas.put(emptyTrack);
      });

      expect(
        () async => await isarService
            .exportTrackToCsvInOpenSenseMapFormat(emptyTrack.id),
        throwsException,
      );
    });
  });

}