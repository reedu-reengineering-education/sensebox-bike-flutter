import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

void main() {
  group('findSensorIdByData', () {
    final boxSensors = [
      Sensor(
        id: "67d937c2b6275400071c38c0",
        title: "Temperature",
        unit: "°C",
      ),
      Sensor(
        id: "67d937c2b6275400071c38c1",
        title: "Rel. Humidity",
        unit: "%",
      ),
      Sensor(
        id: "67d937c2b6275400071c38c2",
        title: "Finedust PM1",
        unit: "µg/m³",
      ),
    ];

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
}