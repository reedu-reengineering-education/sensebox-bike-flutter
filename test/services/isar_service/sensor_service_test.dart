import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import '../../mocks.dart';
import '../../test_helpers.dart';

void main() {
  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/path_provider');
  late MockIsarService mockIsarService;
  late MockSensorService mockSensorService;
  late Isar isar;
  late SensorService sensorService;
  late SensorData sensorData;

  setUpAll(() {
    // Register a fallback value for SensorData
    registerFallbackValue(FakeSensorData());
  });

  setUp(() async {
    initializeTestDependencies();

    // Mock the path_provider plugin
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '/mocked_directory';
      }
      return null;
    });
    
    mockIsarService = MockIsarService();
    mockSensorService = MockSensorService();

    // Mock the sensorService in IsarService
    when(() => mockIsarService.sensorService).thenReturn(mockSensorService);

    // Mock the saveSensorData method to return a Future<int>
    when(() => mockSensorService.saveSensorData(any()))
        .thenAnswer((_) async => 1);
    // Initialize in-memory Isar database
    await Isar.initializeIsarCore(download: true);
    isar = await Isar.open(
      [TrackDataSchema, GeolocationDataSchema, SensorDataSchema],
      directory: '',
    );

    // Mock IsarProvider to return the in-memory Isar instance
    final mockIsarProvider = MockIsarProvider();
    when(() => mockIsarProvider.getDatabase()).thenAnswer((_) async => isar);

    // Initialize SensorService with the mocked IsarProvider
    sensorService = SensorService(isarProvider: mockIsarProvider);

    // Clear the database to ensure test isolation
    await isar.writeTxn(() async {
      await isar.sensorDatas.clear();
      await isar.geolocationDatas.clear();
      await isar.trackDatas.clear();
    });

    final trackData = TrackData();
    await isar.writeTxn(() async {
      await isar.trackDatas.put(trackData);
    });

    final geolocationData = GeolocationData()
      ..latitude = 52.5200
      ..longitude = 13.4050
      ..timestamp = DateTime.now().toUtc()
      ..speed = 0.0
      ..track.value = trackData;

    await isar.writeTxn(() async {
      await isar.geolocationDatas.put(geolocationData);
      await geolocationData.track.save();
    });

    // Add sample sensor data to the database
    sensorData = SensorData()
      ..title = 'temperature'
      ..value = 25.0
      ..attribute = 'Celsius'
      ..characteristicUuid = '1234-5678-9012-3456'
      ..geolocationData.value = geolocationData;

    await isar.writeTxn(() async {
      await isar.sensorDatas.put(sensorData);
      await sensorData.geolocationData.save();
    });
  });

  tearDown(() async {
    await isar.close();
    channel.setMockMethodCallHandler(null);
  });

  group('SensorService', () {
    group('deleteAllSensorData', () {
      test('successfully deletes all sensor data from the database', () async {
        final sensorsBefore = await isar.sensorDatas.where().findAll();
        expect(sensorsBefore.length, equals(1));

        await sensorService.deleteAllSensorData();

        final sensorsAfter = await isar.sensorDatas.where().findAll();
        expect(sensorsAfter.isEmpty, isTrue);
      });

      test('handles empty database gracefully', () async {
        await sensorService.deleteAllSensorData();

        await sensorService.deleteAllSensorData();

        final sensorsAfter = await isar.sensorDatas.where().findAll();
        expect(sensorsAfter.isEmpty, isTrue);
      });

      test('deletes multiple sensor data records from the database', () async {
        final sensorData2 = SensorData()
          ..title = 'humidity'
          ..value = 60.0
          ..attribute = 'Percentage'
          ..characteristicUuid = '1234-5678-9012-3456';

        await isar.writeTxn(() async {
          await isar.sensorDatas.put(sensorData2);
        });

        final sensorsBefore = await isar.sensorDatas.where().findAll();
        expect(sensorsBefore.length, equals(2));

        await sensorService.deleteAllSensorData();

        final sensorsAfter = await isar.sensorDatas.where().findAll();
        expect(sensorsAfter.isEmpty, isTrue);
      });
    });

    group('saveSensorData', () {
      test(
          'should store data for SurfaceAnomalySensor when feature flag is enabled',
          () async {
        FeatureFlags.hideSurfaceAnomalySensor = true; // Enable the feature flag
        final sensorData = SensorData()
          ..title = 'surface_anomaly'
          ..value = 1.23
          ..attribute = 'anomaly_level'
          ..characteristicUuid = '1234-5678-9012-3456';

        await mockSensorService.saveSensorData(sensorData);

        final capturedData =
            verify(() => mockSensorService.saveSensorData(captureAny()))
                .captured
                .single as SensorData;

        expect(capturedData.title, 'surface_anomaly');
        expect(capturedData.value, 1.23);
        expect(capturedData.attribute, 'anomaly_level');
      });

      test('successfully saves sensor data to the database', () async {
        final newSensorData = SensorData()
          ..title = 'pressure'
          ..value = 1013.25
          ..attribute = 'hPa'
          ..characteristicUuid = '5678-1234-9012-3456';

        final sensorId = await sensorService.saveSensorData(newSensorData);

        final savedSensorData = await isar.sensorDatas.get(sensorId);
        expect(savedSensorData, isNotNull);
        expect(savedSensorData?.title, equals('pressure'));
        expect(savedSensorData?.value, equals(1013.25));
        expect(savedSensorData?.attribute, equals('hPa'));
      });
    });

    group('getSensorData', () {
      test('retrieves all sensor data from the database', () async {
        final sensors = await sensorService.getSensorData();
        expect(sensors.length, equals(1));
      });

      test('returns an empty list when no sensor data exists', () async {
        await sensorService.deleteAllSensorData();

        final sensors = await sensorService.getSensorData();
        expect(sensors.isEmpty, isTrue);
      });
    });

    group('getSensorDataByGeolocationId', () {
      test('retrieves sensor data by geolocation ID', () async {
        final geolocationId = sensorData.geolocationData.value?.id ?? -1;
        final sensors =
            await sensorService.getSensorDataByGeolocationId(geolocationId);

        expect(sensors.length, equals(1));
        expect(sensors.first.title, equals('temperature'));
      });

      test('returns an empty list for a non-existent geolocation ID', () async {
        final sensors = await sensorService.getSensorDataByGeolocationId(-1);
        expect(sensors.isEmpty, isTrue);
      });
    });

    group('getSensorDataByTrackId', () {
      test('retrieves sensor data by track ID', () async {
        final trackId = sensorData.geolocationData.value?.track.value?.id ?? -1;
        final sensors = await sensorService.getSensorDataByTrackId(trackId);

        expect(sensors.length, equals(1));
        expect(sensors.first.title, equals('temperature'));
      });

      test('returns an empty list for a non-existent track ID', () async {
        final sensors = await sensorService.getSensorDataByTrackId(-1);
        expect(sensors.isEmpty, isTrue);
      });
    });
  });
}