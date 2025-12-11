import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

void main() {
  final boxSensors = [
    Sensor(id: "67d937c2b6275400071c38c0", title: "Temperature", unit: "°C"),
    Sensor(id: "67d937c2b6275400071c38c1", title: "Rel. Humidity", unit: "%"),
    Sensor(
        id: "67d937c2b6275400071c38c2", title: "Finedust PM1", unit: "µg/m³"),
  ];
  
  group('findSensorIdByData', () {
    test('should return sensor ID when title and attribute match', () {
      final sensorData = SensorData()
        ..title = "finedust"
        ..attribute = "pm1";
      final sensorId = findSensorIdByData(sensorData, boxSensors);

      expect(sensorId, "67d937c2b6275400071c38c2");
    });

    test('should return sensor ID when title matches and attribute is null', () {
      final sensorData = SensorData()
        ..title = "temperature"
        ..attribute = null;

      final sensorId = findSensorIdByData(sensorData, boxSensors);

      expect(sensorId, "67d937c2b6275400071c38c0");
    });

    test('should return null when no matching sensor is found', () {
      final sensorData = SensorData()
        ..title = "unknown"
        ..attribute = null;

      final sensorId = findSensorIdByData(sensorData, boxSensors);

      expect(sensorId, isNull);
    });

    test('should return null when attribute does not match', () {
      final sensorData = SensorData()
        ..title = "finedust"
        ..attribute = "pm15";

      final sensorId = findSensorIdByData(sensorData, boxSensors);

      expect(sensorId, isNull);
    });
  });

  group('createGpsSpeedSensorData', () {
    late GeolocationData mockGeoData;

    setUp(() {
      mockGeoData = GeolocationData()
        ..latitude = 52.52
        ..longitude = 13.405
        ..speed = 15.5
        ..timestamp = DateTime.parse('2025-01-01T12:00:00');
    });

    test('creates GPS speed sensor data correctly', () {
      final sensorData = createGpsSpeedSensorData(mockGeoData);

      expect(sensorData.title, equals('gps')); // Match GPS sensor format
      expect(sensorData.attribute, equals('speed')); // Match GPS sensor format
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

      expect(shouldStoreSensorData(sensorData), isTrue);
    });

    test('returns false for NaN values', () {
      final sensorData = SensorData()
        ..title = 'temperature'
        ..value = double.nan;

      expect(shouldStoreSensorData(sensorData), isFalse);
    });

    test('returns false for infinite values', () {
      final sensorData = SensorData()
        ..title = 'temperature'
        ..value = double.infinity;

      expect(shouldStoreSensorData(sensorData), isFalse);
    });

    test('returns false for zero GPS coordinates', () {
      final sensorData = SensorData()
        ..title = 'gps'
        ..attribute = 'latitude'
        ..value = 0.0;

      expect(shouldStoreSensorData(sensorData), isFalse);
    });
  });

  group('findSpeedSensorId', () {
    test('returns exact speed sensor match', () {
      final speedSensor = Sensor(id: 'speedId', title: 'Speed');
      final senseBox = SenseBox(sensors: [speedSensor]);

      final result = findSpeedSensorId(senseBox);

      expect(result, 'speedId');
    });

    test('matches speed sensor case-insensitively', () {
      final speedSensor = Sensor(id: 'speedId', title: 'SPEED');
      final senseBox = SenseBox(sensors: [speedSensor]);

      final result = findSpeedSensorId(senseBox);

      expect(result, 'speedId');
    });

    test('matches sensor with speed in title', () {
      final speedSensor = Sensor(id: 'speedId', title: 'speed sensor');
      final senseBox = SenseBox(sensors: [speedSensor]);

      final result = findSpeedSensorId(senseBox);

      expect(result, 'speedId');
    });

    test('returns null when no speed sensor found', () {
      final senseBox = SenseBox(sensors: []);

      final result = findSpeedSensorId(senseBox);

      expect(result, isNull);
    });
  });

  group('addSpeedEntries', () {
    test('adds speed entries for each gps point', () {
      final speedSensorId = 'speedId';
      final gpsPoints = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];
      final target = <String, dynamic>{};

      addSpeedEntries(
        target: target,
        gpsBuffer: gpsPoints,
        speedSensorId: speedSensorId,
      );

      expect(target.length, 1);
      final entry = target.values.first as Map<String, dynamic>;
      expect(entry['sensor'], speedSensorId);
      expect(entry['value'], '5.00');
      expect(entry['location']['lat'], 10.0);
      expect(entry['location']['lng'], 20.0);
    });
  });
}