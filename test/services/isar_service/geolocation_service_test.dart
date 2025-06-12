import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import '../../mocks.dart';
import '../../test_helpers.dart';

void main() {
  late Isar isar;
  late GeolocationService geolocationService;
  late GeolocationData geolocationData;
  late Directory tempDirectory;

  setUp(() async {
    initializeTestDependencies();

    tempDirectory = Directory.systemTemp.createTempSync();
    mockPathProvider(tempDirectory.path);

    isar = await initializeInMemoryIsar();
    final mockIsarProvider = MockIsarProvider();
    when(() => mockIsarProvider.getDatabase()).thenAnswer((_) async => isar);

    geolocationService = GeolocationService(isarProvider: mockIsarProvider);

    await clearIsarDatabase(isar);
    
    geolocationData = GeolocationData()
      ..latitude = 52.5200
      ..longitude = 13.4050
      ..timestamp = DateTime.now().toUtc()
      ..speed = 0.0;

    await isar.writeTxn(() async {
      await isar.geolocationDatas.put(geolocationData);
    });
  });

  tearDown(() async {
    await isar.close();
  });

  group('GeolocationService', () {
    group('deleteAllGeolocations', () {
      test('successfully deletes all geolocations from the database', () async {
        // Verify that the geolocation data exists before deletion
        final geolocationsBefore =
            await isar.geolocationDatas.where().findAll();
        expect(geolocationsBefore.length, equals(1));

        await geolocationService.deleteAllGeolocations();

        final geolocationsAfter = await isar.geolocationDatas.where().findAll();
        expect(geolocationsAfter.isEmpty, isTrue);
      });

      test('handles empty database gracefully', () async {
        await geolocationService.deleteAllGeolocations();

        final geolocationsAfter = await isar.geolocationDatas.where().findAll();
        expect(geolocationsAfter.isEmpty, isTrue);
      });

      test('deletes multiple geolocations from the database', () async {
        final geolocationData2 = GeolocationData()
          ..latitude = 48.8566
          ..longitude = 2.3522
          ..timestamp = DateTime.now().toUtc()
          ..speed = 10.0;

        await isar.writeTxn(() async {
          await isar.geolocationDatas.put(geolocationData2);
        });

        // Verify that multiple geolocation records exist before deletion
        final geolocationsBefore =
            await isar.geolocationDatas.where().findAll();
        expect(geolocationsBefore.length, equals(2));

        await geolocationService.deleteAllGeolocations();

        final geolocationsAfter = await isar.geolocationDatas.where().findAll();
        expect(geolocationsAfter.isEmpty, isTrue);
      });
    });

    group('getGeolocationData', () {
      test('retrieves all geolocation data from the database', () async {
        final geolocations = await geolocationService.getGeolocationData();

        expect(geolocations.length, equals(1));
        expect(geolocations.first.latitude, equals(52.5200));
        expect(geolocations.first.longitude, equals(13.4050));
      });

      test('returns an empty list when no geolocation data exists', () async {
        await geolocationService.deleteAllGeolocations();

        final geolocations = await geolocationService.getGeolocationData();

        expect(geolocations.isEmpty, isTrue);
      });
    });

    group('getGeolocationDataByTrackId', () {
      test('retrieves geolocation data by track ID', () async {
        final trackData = TrackData();
        await isar.writeTxn(() async {
          await isar.trackDatas.put(trackData);
        });

        geolocationData.track.value = trackData;
        await isar.writeTxn(() async {
          await geolocationData.track.save();
        });

        final geolocations =
            await geolocationService.getGeolocationDataByTrackId(trackData.id);

        expect(geolocations.length, equals(1));
        expect(geolocations.first.latitude, equals(52.5200));
        expect(geolocations.first.longitude, equals(13.4050));
      });

      test(
          'returns an empty list when no geolocation data exists for the track ID',
          () async {
        final geolocations =
            await geolocationService.getGeolocationDataByTrackId(-1);

        expect(geolocations.isEmpty, isTrue);
      });
    });

    group('getLastGeolocationData', () {
      test('retrieves the most recent geolocation data', () async {
        final geolocationData2 = GeolocationData()
          ..latitude = 48.8566
          ..longitude = 2.3522
          ..timestamp = DateTime.now().add(const Duration(hours: 1)).toUtc()
          ..speed = 10.0;

        await isar.writeTxn(() async {
          await isar.geolocationDatas.put(geolocationData2);
        });

        final lastGeolocation =
            await geolocationService.getLastGeolocationData();

        expect(lastGeolocation?.latitude, equals(48.8566));
        expect(lastGeolocation?.longitude, equals(2.3522));
      });

      test('returns null when no geolocation data exists', () async {
        await geolocationService.deleteAllGeolocations();

        final lastGeolocation =
            await geolocationService.getLastGeolocationData();

        expect(lastGeolocation, isNull);
      });
  });
});
}