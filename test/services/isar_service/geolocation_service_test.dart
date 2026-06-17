import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
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

    final trackData = createMockTrackData();
    await isar.writeTxn(() async {
      await isar.trackDatas.put(trackData);
    });

    geolocationData = createMockGeolocationData(trackData);
    await isar.writeTxn(() async {
      await isar.geolocationDatas.put(geolocationData);
      await geolocationData.track.save();
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

    group('discoverAvailableSensorsFromGeolocations', () {
      test('unions sensor types from the first geolocations only', () async {
        final trackData = createMockTrackData();
        await isar.writeTxn(() async {
          await isar.trackDatas.put(trackData);
        });

        final geoWithTemperature = GeolocationData()
          ..latitude = 52.5200
          ..longitude = 13.4050
          ..timestamp = DateTime.utc(2024, 1, 1, 10)
          ..speed = 0.0
          ..track.value = trackData;
        final geoWithHumidity = GeolocationData()
          ..latitude = 52.5201
          ..longitude = 13.4051
          ..timestamp = DateTime.utc(2024, 1, 1, 11)
          ..speed = 0.0
          ..track.value = trackData;

        await isar.writeTxn(() async {
          await isar.geolocationDatas.putAll([
            geoWithTemperature,
            geoWithHumidity,
          ]);
          await geoWithTemperature.track.save();
          await geoWithHumidity.track.save();
        });

        final temperatureSensor = SensorData()
          ..title = 'temperature'
          ..value = 20.0
          ..attribute = null
          ..characteristicUuid = 'temp-uuid'
          ..geolocationData.value = geoWithTemperature;
        final humiditySensor = SensorData()
          ..title = 'humidity'
          ..value = 55.0
          ..attribute = null
          ..characteristicUuid = 'humidity-uuid'
          ..geolocationData.value = geoWithHumidity;

        await isar.writeTxn(() async {
          await isar.sensorDatas.putAll([temperatureSensor, humiditySensor]);
          await temperatureSensor.geolocationData.save();
          await humiditySensor.geolocationData.save();
        });

        final geolocations =
            await geolocationService.getGeolocationDataByTrackId(trackData.id);
        expect(geolocations.length, equals(2));

        final discovered = await geolocationService
            .discoverAvailableSensorsFromGeolocations(
          geolocations,
          sampleSize: 1,
        );

        expect(discovered.length, equals(1));
        expect(discovered.first.title, equals('temperature'));
      });

      test('returns sensors sorted by canonical order', () async {
        final trackData = createMockTrackData();
        await isar.writeTxn(() async {
          await isar.trackDatas.put(trackData);
        });

        final geo = GeolocationData()
          ..latitude = 52.5200
          ..longitude = 13.4050
          ..timestamp = DateTime.utc(2024, 1, 1, 10)
          ..speed = 0.0
          ..track.value = trackData;

        await isar.writeTxn(() async {
          await isar.geolocationDatas.put(geo);
          await geo.track.save();
        });

        final humiditySensor = SensorData()
          ..title = 'humidity'
          ..value = 55.0
          ..attribute = null
          ..characteristicUuid = 'humidity-uuid'
          ..geolocationData.value = geo;
        final temperatureSensor = SensorData()
          ..title = 'temperature'
          ..value = 20.0
          ..attribute = null
          ..characteristicUuid = 'temp-uuid'
          ..geolocationData.value = geo;

        await isar.writeTxn(() async {
          await isar.sensorDatas.putAll([humiditySensor, temperatureSensor]);
          await humiditySensor.geolocationData.save();
          await temperatureSensor.geolocationData.save();
        });

        final geolocations =
            await geolocationService.getGeolocationDataByTrackId(trackData.id);
        final discovered = await geolocationService
            .discoverAvailableSensorsFromGeolocations(geolocations);

        expect(discovered.map((sensor) => sensor.title).toList(),
            equals(['temperature', 'humidity']));
      });
  });
});
}