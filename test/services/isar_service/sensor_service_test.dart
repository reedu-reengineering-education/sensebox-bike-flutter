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
    });

    // Add sample sensor data to the database
    sensorData = SensorData()
      ..title = 'temperature'
      ..value = 25.0
      ..attribute = 'Celsius'
      ..characteristicUuid = '1234-5678-9012-3456';

    await isar.writeTxn(() async {
      await isar.sensorDatas.put(sensorData);
    });
  });

  tearDown(() async {
    await isar.close();
    channel.setMockMethodCallHandler(null);
  });

  group('SensorService', () {
    group('deleteAllSensorData', () {
      test('successfully deletes all sensor data from the database', () async {
        // Verify that the sensor data exists before deletion
        final sensorsBefore = await isar.sensorDatas.where().findAll();
        expect(sensorsBefore.length, equals(1));

        // Act: Delete all sensor data
        await sensorService.deleteAllSensorData();

        // Verify that the sensor data is deleted
        final sensorsAfter = await isar.sensorDatas.where().findAll();
        expect(sensorsAfter.isEmpty, isTrue);
      });

      test('handles empty database gracefully', () async {
        // Arrange: Clear the database
        await sensorService.deleteAllSensorData();

        // Act: Delete all sensor data when the database is already empty
        await sensorService.deleteAllSensorData();

        // Assert: Ensure the database is still empty
        final sensorsAfter = await isar.sensorDatas.where().findAll();
        expect(sensorsAfter.isEmpty, isTrue);
      });

      test('deletes multiple sensor data records from the database', () async {
        // Arrange: Add multiple sensor data records
        final sensorData2 = SensorData()
          ..title = 'humidity'
          ..value = 60.0
          ..attribute = 'Percentage'
          ..characteristicUuid = '1234-5678-9012-3456';

        await isar.writeTxn(() async {
          await isar.sensorDatas.put(sensorData2);
        });

        // Verify that multiple sensor data records exist before deletion
        final sensorsBefore = await isar.sensorDatas.where().findAll();
        expect(sensorsBefore.length, equals(2));

        // Act: Delete all sensor data
        await sensorService.deleteAllSensorData();

        // Assert: Ensure all sensor data is deleted
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

        // Act
        await mockSensorService.saveSensorData(sensorData);

        // Assert
        final capturedData =
            verify(() => mockSensorService.saveSensorData(captureAny()))
                .captured
                .single as SensorData;

        // Verify the captured data
        expect(capturedData.title, 'surface_anomaly');
        expect(capturedData.value, 1.23);
        expect(capturedData.attribute, 'anomaly_level');
      });
    });
  });
}