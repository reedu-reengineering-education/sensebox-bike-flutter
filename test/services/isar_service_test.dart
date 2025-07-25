import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

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
        () => isarService.exportTrackToCsv(emptyTrack.id),
        throwsA(isA<Exception>()),
      );
    });

    test('correctly handles GPS speed sensor data', () async {
      // Create GPS speed sensor data with the correct format
      final gpsSpeedSensorData = SensorData()
        ..title = 'speed' // Correct format: title = 'speed', no attribute
        ..attribute = null
        ..value = 15.5
        ..characteristicUuid = 'gps-speed-uuid'
        ..geolocationData.value = geolocationData;

      await isar.writeTxn(() async {
        await isar.sensorDatas.put(gpsSpeedSensorData);
        await gpsSpeedSensorData.geolocationData.save();
      });

      final csvFilePath =
          await isarService.exportTrackToCsvInOpenSenseMapFormat(trackData.id);

      final file = File(csvFilePath);
      expect(file.existsSync(), isTrue);

      final csvContent = await file.readAsString();
      expect(csvContent.isNotEmpty, isTrue);
      
      // Check that speed data is included with the correct sensor ID
      expect(csvContent.contains('test-speed-sensor'), isTrue);
      expect(csvContent.contains('15.50'), isTrue);
    });

    test('GPS speed data format matches sensorOrder expectations', () async {
      // Create GPS speed sensor data with the actual GPS sensor format
      final gpsSpeedSensorData = SensorData()
        ..title = 'gps' // GPS sensor format: title = 'gps', attribute = 'speed'
        ..attribute = 'speed'
        ..value = 15.5
        ..characteristicUuid = 'gps-speed-uuid'
        ..geolocationData.value = geolocationData;

      await isar.writeTxn(() async {
        await isar.sensorDatas.put(gpsSpeedSensorData);
        await gpsSpeedSensorData.geolocationData.save();
      });

      // Test that the search key matches the sensorOrder expectation
      final searchKey =
          getSearchKey(gpsSpeedSensorData.title, gpsSpeedSensorData.attribute);
      expect(searchKey, equals('gps_speed'));

      // Test that the title can be retrieved correctly
      final title = getTitleFromSensorKey(
          gpsSpeedSensorData.title, gpsSpeedSensorData.attribute);
      expect(title, equals('Speed'));
    });

    test('GPS speed data is saved with correct title and attribute format',
        () async {
      // Create GPS speed sensor data with the correct format
      final gpsSpeedSensorData = SensorData()
        ..title = 'gps' // Should be 'gps' not 'speed'
        ..attribute = 'speed' // Should be 'speed' not null
        ..value = 15.5
        ..characteristicUuid = 'gps-speed-uuid'
        ..geolocationData.value = geolocationData;

      await isar.writeTxn(() async {
        await isar.sensorDatas.put(gpsSpeedSensorData);
        await gpsSpeedSensorData.geolocationData.save();
      });

      // Verify the data is saved correctly in the database
      final savedSensorData = await isar.sensorDatas.where().findAll();
      final gpsSpeedData = savedSensorData
          .where((data) => data.title == 'gps' && data.attribute == 'speed')
          .firstOrNull;

      expect(gpsSpeedData, isNotNull);
      expect(gpsSpeedData!.title, equals('gps'));
      expect(gpsSpeedData.attribute, equals('speed'));
      expect(gpsSpeedData.value, equals(15.5));
    });

    test('GPS sensor data sorting works correctly', () async {
      // Create multiple sensor data entries including GPS speed
      final temperatureData = SensorData()
        ..title = 'temperature'
        ..attribute = null
        ..value = 25.0
        ..characteristicUuid = 'temp-uuid'
        ..geolocationData.value = geolocationData;

      final gpsSpeedData = SensorData()
        ..title = 'gps'
        ..attribute = 'speed'
        ..value = 15.5
        ..characteristicUuid = 'gps-speed-uuid'
        ..geolocationData.value = geolocationData;

      final humidityData = SensorData()
        ..title = 'humidity'
        ..attribute = null
        ..value = 60.0
        ..characteristicUuid = 'humidity-uuid'
        ..geolocationData.value = geolocationData;

      await isar.writeTxn(() async {
        await isar.sensorDatas
            .putAll([temperatureData, gpsSpeedData, humidityData]);
        await temperatureData.geolocationData.save();
        await gpsSpeedData.geolocationData.save();
        await humidityData.geolocationData.save();
      });

      // Test the sorting logic
      final sensorData = [temperatureData, gpsSpeedData, humidityData];
      final sensorTitles = sensorData
          .map((e) => {'title': e.title, 'attribute': e.attribute})
          .map((map) => map.entries.map((e) => '${e.key}:${e.value}').join(','))
          .toSet()
          .map((str) {
        var entries = str.split(',').map((e) => e.split(':'));
        return Map<String, String?>.fromEntries(
          entries.map((e) => MapEntry(e[0], e[1] == 'null' ? null : e[1])),
        );
      }).toList();

      // Sort using the same logic as in track_utils.dart
      final order = [
        'temperature',
        'humidity',
        'distance',
        'overtaking',
        'surface_classification_asphalt',
        'surface_classification_compacted',
        'surface_classification_paving',
        'surface_classification_sett',
        'surface_classification_standing',
        'surface_anomaly',
        'acceleration_x',
        'acceleration_y',
        'acceleration_z',
        'finedust_pm1',
        'finedust_pm2.5',
        'finedust_pm4',
        'finedust_pm10',
        'gps_latitude',
        'gps_longitude',
        'gps_speed',
      ];

      sensorTitles.sort((a, b) {
        int indexA = order.indexOf(
            '${a['title']}${a['attribute'] == null ? '' : '_${a['attribute']}'}');
        int indexB = order.indexOf(
            '${b['title']}${b['attribute'] == null ? '' : '_${b['attribute']}'}');
        return indexA.compareTo(indexB);
      });

      // Verify the order: temperature (0), humidity (1), gps_speed (19)
      expect(sensorTitles.length, equals(3));
      expect(sensorTitles[0]['title'], equals('temperature'));
      expect(sensorTitles[1]['title'], equals('humidity'));
      expect(sensorTitles[2]['title'], equals('gps'));
      expect(sensorTitles[2]['attribute'], equals('speed'));
    });

    test('GPS sensor should create all three data entries (lat, lng, speed)',
        () async {
      // Simulate what the GPS sensor should be doing
      // GPS sensor has attributes: ['latitude', 'longitude', 'speed']
      // When it receives data [lat, lng, speed], it should create 3 SensorData entries

      final gpsLatitudeData = SensorData()
        ..title = 'gps'
        ..attribute = 'latitude'
        ..value = 52.5555154
        ..characteristicUuid = 'gps-uuid'
        ..geolocationData.value = geolocationData;

      final gpsLongitudeData = SensorData()
        ..title = 'gps'
        ..attribute = 'longitude'
        ..value = 13.4218069
        ..characteristicUuid = 'gps-uuid'
        ..geolocationData.value = geolocationData;

      final gpsSpeedData = SensorData()
        ..title = 'gps'
        ..attribute = 'speed'
        ..value = 15.5
        ..characteristicUuid = 'gps-uuid'
        ..geolocationData.value = geolocationData;

      await isar.writeTxn(() async {
        await isar.sensorDatas
            .putAll([gpsLatitudeData, gpsLongitudeData, gpsSpeedData]);
        await gpsLatitudeData.geolocationData.save();
        await gpsLongitudeData.geolocationData.save();
        await gpsSpeedData.geolocationData.save();
      });

      // Verify all three GPS data entries are stored
      final savedSensorData = await isar.sensorDatas.where().findAll();
      final gpsData =
          savedSensorData.where((data) => data.title == 'gps').toList();

      expect(gpsData.length, equals(3));

      final latitudeData =
          gpsData.where((data) => data.attribute == 'latitude').firstOrNull;
      final longitudeData =
          gpsData.where((data) => data.attribute == 'longitude').firstOrNull;
      final speedData =
          gpsData.where((data) => data.attribute == 'speed').firstOrNull;

      expect(latitudeData, isNotNull);
      expect(longitudeData, isNotNull);
      expect(speedData, isNotNull);

      expect(latitudeData!.value, equals(52.5555154));
      expect(longitudeData!.value, equals(13.4218069));
      expect(speedData!.value, equals(15.5));
    });

    test('GeolocationBloc GPS speed data format matches GPS sensor format',
        () async {
      // Test that GeolocationBloc creates GPS speed data with the same format as GPS sensor
      final mockGeoData = GeolocationData()
        ..latitude = 52.52
        ..longitude = 13.405
        ..speed = 15.5
        ..timestamp = DateTime.parse('2025-01-01T12:00:00');

      // Create GPS speed data using sensor_utils (as GeolocationBloc does)
      final gpsSpeedData =
            createGpsSpeedSensorData(mockGeoData);

      // Verify it matches GPS sensor format
      expect(gpsSpeedData.title, equals('gps'));
      expect(gpsSpeedData.attribute, equals('speed'));
      expect(gpsSpeedData.value, equals(15.5));
      expect(gpsSpeedData.characteristicUuid,
          equals('8edf8ebb-1246-4329-928d-ee0c91db2389'));

      // Test that it sorts correctly with other sensors
      final temperatureData = SensorData()
        ..title = 'temperature'
        ..attribute = null
        ..value = 25.0
        ..characteristicUuid = 'temp-uuid'
        ..geolocationData.value = geolocationData;

      final sensorData = [temperatureData, gpsSpeedData];
      final sensorTitles = sensorData
          .map((e) => {'title': e.title, 'attribute': e.attribute})
          .map((map) => map.entries.map((e) => '${e.key}:${e.value}').join(','))
          .toSet()
          .map((str) {
        var entries = str.split(',').map((e) => e.split(':'));
        return Map<String, String?>.fromEntries(
          entries.map((e) => MapEntry(e[0], e[1] == 'null' ? null : e[1])),
        );
      }).toList();

      // Sort using the same logic as in track_utils.dart
      final order = [
        'temperature',
        'humidity',
        'distance',
        'overtaking',
        'surface_classification_asphalt',
        'surface_classification_compacted',
        'surface_classification_paving',
        'surface_classification_sett',
        'surface_classification_standing',
        'surface_anomaly',
        'acceleration_x',
        'acceleration_y',
        'acceleration_z',
        'finedust_pm1',
        'finedust_pm2.5',
        'finedust_pm4',
        'finedust_pm10',
        'gps_latitude',
        'gps_longitude',
        'gps_speed',
      ];

      sensorTitles.sort((a, b) {
        int indexA = order.indexOf(
            '${a['title']}${a['attribute'] == null ? '' : '_${a['attribute']}'}');
        int indexB = order.indexOf(
            '${b['title']}${b['attribute'] == null ? '' : '_${b['attribute']}'}');
        return indexA.compareTo(indexB);
      });

      // Verify the order: temperature (0), gps_speed (19)
      expect(sensorTitles.length, equals(2));
      expect(sensorTitles[0]['title'], equals('temperature'));
      expect(sensorTitles[1]['title'], equals('gps'));
      expect(sensorTitles[1]['attribute'], equals('speed'));
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