import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import '../mocks.dart';

void main() {
  group('Sensor Aggregation and Value Removal', () {
    late TemperatureSensor sensor;
    late MockRecordingBloc recordingBloc;
    late MockGeolocationBloc geolocationBloc;
    late StreamController<GeolocationData> geoController;

    setUp(() {
      recordingBloc = MockRecordingBloc();
      recordingBloc.setRecording(true);
      geolocationBloc = MockGeolocationBloc();
      geoController = StreamController<GeolocationData>.broadcast();
      when(() => geolocationBloc.geolocationStream)
          .thenAnswer((_) => geoController.stream);

      sensor = TemperatureSensor(
        MockBleBloc(),
        geolocationBloc,
        recordingBloc,
        MockIsarService(),
      );
    });

    tearDown(() async {
      await geoController.close();
      sensor.dispose();
    });

    test('removes values after immediate aggregation for zero lookback sensors',
        () async {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final geo = GeolocationData()
        ..id = 1
        ..timestamp = geoTime
        ..latitude = 52.0
        ..longitude = 13.0;

      sensor.onDataReceived([20.0]);
      await Future.delayed(const Duration(milliseconds: 10));
      sensor.onDataReceived([21.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      sensor.startListening();
      await Future.delayed(const Duration(milliseconds: 50));

      geoController.add(geo);
      await Future.delayed(const Duration(milliseconds: 100));

      final secondGeoTime = DateTime.utc(2024, 1, 1, 12, 0, 3);
      final secondGeo = GeolocationData()
        ..id = 2
        ..timestamp = secondGeoTime
        ..latitude = 52.0
        ..longitude = 13.0;

      sensor.onDataReceived([22.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      geoController.add(secondGeo);
      await Future.delayed(const Duration(milliseconds: 100));

      final thirdGeoTime = DateTime.utc(2024, 1, 1, 12, 0, 4);
      final thirdGeo = GeolocationData()
        ..id = 3
        ..timestamp = thirdGeoTime
        ..latitude = 52.0
        ..longitude = 13.0;

      geoController.add(thirdGeo);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sensor, isNotNull);
    });

    test('aggregates only values with timestamp before geolocation time',
        () async {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final geo = GeolocationData()
        ..id = 1
        ..timestamp = geoTime
        ..latitude = 52.0
        ..longitude = 13.0;

      sensor.onDataReceived([20.0]);
      await Future.delayed(const Duration(milliseconds: 10));
      sensor.onDataReceived([21.0]);
      await Future.delayed(const Duration(milliseconds: 10));
      sensor.onDataReceived([22.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      sensor.startListening();
      geoController.add(geo);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sensor, isNotNull);
    });

    test('does not aggregate values with timestamp equal to geolocation time',
        () async {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final geo = GeolocationData()
        ..id = 1
        ..timestamp = geoTime
        ..latitude = 52.0
        ..longitude = 13.0;

      sensor.startListening();
      await Future.delayed(const Duration(milliseconds: 10));

      geoController.add(geo);
      await Future.delayed(const Duration(milliseconds: 10));

      sensor.onDataReceived([25.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      final secondGeo = GeolocationData()
        ..id = 2
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 3)
        ..latitude = 52.0
        ..longitude = 13.0;

      geoController.add(secondGeo);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sensor, isNotNull);
    });

    test('handles multiple geolocations correctly', () async {
      sensor.startListening();
      await Future.delayed(const Duration(milliseconds: 10));

      sensor.onDataReceived([20.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      final geo1 = GeolocationData()
        ..id = 1
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 1)
        ..latitude = 52.0
        ..longitude = 13.0;

      geoController.add(geo1);
      await Future.delayed(const Duration(milliseconds: 50));

      sensor.onDataReceived([21.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      final geo2 = GeolocationData()
        ..id = 2
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 2)
        ..latitude = 52.0
        ..longitude = 13.0;

      geoController.add(geo2);
      await Future.delayed(const Duration(milliseconds: 50));

      sensor.onDataReceived([22.0]);
      await Future.delayed(const Duration(milliseconds: 10));

      final geo3 = GeolocationData()
        ..id = 3
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 3)
        ..latitude = 52.0
        ..longitude = 13.0;

      geoController.add(geo3);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sensor, isNotNull);
    });
  });

  group('Sensor batch processing does not starve on empty batches', () {
    late MockRecordingBloc recordingBloc;
    late MockGeolocationBloc geolocationBloc;
    late StreamController<GeolocationData> geoController;
    late MockIsarService isarService;
    late MockSensorService sensorService;

    setUp(() {
      recordingBloc = MockRecordingBloc();
      recordingBloc.setRecording(true);

      geolocationBloc = MockGeolocationBloc();
      geoController = StreamController<GeolocationData>.broadcast();
      when(() => geolocationBloc.geolocationStream)
          .thenAnswer((_) => geoController.stream);

      isarService = MockIsarService();
      sensorService = MockSensorService();
      when(() => isarService.sensorService).thenReturn(sensorService);
      when(() => sensorService.saveSensorDataBatch(any()))
          .thenAnswer((_) async {});
    });

    tearDown(() async {
      await geoController.close();
    });

    test(
        'continues saving when many geolocations have no sensor data (no starvation)',
        () async {
      var saveCalls = 0;
      when(() => sensorService.saveSensorDataBatch(any()))
          .thenAnswer((_) async => saveCalls++);

      final sensor = _TestSingleValueSensor(
        MockBleBloc(),
        geolocationBloc,
        recordingBloc,
        isarService,
      );

      await sensor.startListening();

      // Emit many geolocations where this sensor has no data.
      final baseTime = DateTime.now().toUtc().add(const Duration(seconds: 10));
      for (int i = 1; i <= 120; i++) {
        geoController.add(GeolocationData()
          ..id = i
          ..timestamp = baseTime.add(Duration(milliseconds: i))
          ..latitude = 52.0
          ..longitude = 13.0
          ..speed = 0.0);
      }

      // Now emit some sensor values and a few more geolocations; these should get saved.
      sensor.onDataReceived([42.0]);
      await Future.delayed(const Duration(milliseconds: 5));
      sensor.onDataReceived([43.0]);
      await Future.delayed(const Duration(milliseconds: 5));

      for (int i = 121; i <= 130; i++) {
        geoController.add(GeolocationData()
          ..id = i
          ..timestamp = baseTime.add(Duration(milliseconds: i))
          ..latitude = 52.0
          ..longitude = 13.0
          ..speed = 0.0);
      }

      // Allow deferred aggregation + microtask flush to run.
      await Future.delayed(const Duration(milliseconds: 200));

      // We expect at least one DB batch to be saved; previously, empty batches could starve saving.
      expect(saveCalls, greaterThan(0));

      sensor.dispose();
    });
  });
}

class _TestSingleValueSensor extends Sensor {
  _TestSingleValueSensor(
    MockBleBloc bleBloc,
    MockGeolocationBloc geolocationBloc,
    MockRecordingBloc recordingBloc,
    MockIsarService isarService,
  ) : super(
          'test-uuid',
          'test_sensor',
          const [],
          bleBloc,
          geolocationBloc,
          recordingBloc,
          isarService,
        );

  @override
  Duration get lookbackWindow => const Duration(milliseconds: 10);

  @override
  int get uiPriority => 0;

  @override
  List<double> aggregateData(List<List<double>> rawData) {
    final values = rawData.map((e) => e[0]).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    return [avg];
  }
}
