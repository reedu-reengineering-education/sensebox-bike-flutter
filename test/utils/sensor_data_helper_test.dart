import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/utils/sensor_data_helper.dart';

void main() {
  group('SensorDataHelper', () {
    late GeolocationData mockGeoData;

    setUp(() {
      mockGeoData = GeolocationData()
        ..latitude = 52.52
        ..longitude = 13.405
        ..speed = 15.5
        ..timestamp = DateTime.parse('2025-01-01T12:00:00');
    });

    group('createGpsSpeedSensorData', () {
      test('creates GPS speed sensor data correctly', () {
        final sensorData = SensorDataHelper.createGpsSpeedSensorData(mockGeoData);

        expect(
            sensorData.title, equals('gps')); // Match GPS sensor format
        expect(
            sensorData.attribute, equals('speed')); // Match GPS sensor format
        expect(sensorData.value, equals(15.5));
        expect(sensorData.characteristicUuid,
            equals('8edf8ebb-1246-4329-928d-ee0c91db2389'));
        expect(sensorData.geolocationData.value, equals(mockGeoData));
      });
    });
    group('shouldStoreSensorData', () {
      test('returns true for valid sensor data', () {
        final sensorData = SensorData()
          ..title = 'temperature'
          ..value = 22.5;

        expect(SensorDataHelper.shouldStoreSensorData(sensorData), isTrue);
      });

      test('returns false for NaN values', () {
        final sensorData = SensorData()
          ..title = 'temperature'
          ..value = double.nan;

        expect(SensorDataHelper.shouldStoreSensorData(sensorData), isFalse);
      });

      test('returns false for infinite values', () {
        final sensorData = SensorData()
          ..title = 'temperature'
          ..value = double.infinity;

        expect(SensorDataHelper.shouldStoreSensorData(sensorData), isFalse);
      });

      test('returns false for zero GPS coordinates', () {
        final sensorData = SensorData()
          ..title = 'gps'
          ..attribute = 'latitude'
          ..value = 0.0;

        expect(SensorDataHelper.shouldStoreSensorData(sensorData), isFalse);
      });
    });
  });
} 