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

        expect(sensorData.title, equals('gps'));
        expect(sensorData.attribute, equals('speed'));
        expect(sensorData.value, equals(15.5));
        expect(sensorData.characteristicUuid, equals('gps_speed_from_geolocation'));
        expect(sensorData.geolocationData.value, equals(mockGeoData));
      });
    });

    group('createSurfaceAnomalySensorData', () {
      test('creates surface anomaly sensor data correctly', () {
        final sensorData = SensorDataHelper.createSurfaceAnomalySensorData(
          mockGeoData,
          2.5,
          'test-uuid',
        );

        expect(sensorData.title, equals('surface_anomaly'));
        expect(sensorData.attribute, equals('anomaly_level'));
        expect(sensorData.value, equals(2.5));
        expect(sensorData.characteristicUuid, equals('test-uuid'));
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

    group('getSensorKey', () {
      test('returns correct key for sensor with attribute', () {
        final sensorData = SensorData()
          ..title = 'gps'
          ..attribute = 'speed';

        expect(SensorDataHelper.getSensorKey(sensorData), equals('gps_speed'));
      });

      test('returns correct key for sensor without attribute', () {
        final sensorData = SensorData()
          ..title = 'temperature'
          ..attribute = null;

        expect(SensorDataHelper.getSensorKey(sensorData), equals('temperature'));
      });
    });
  });
} 