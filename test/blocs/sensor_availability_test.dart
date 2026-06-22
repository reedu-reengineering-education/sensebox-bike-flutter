import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/sensor_availability.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/sensors/surface_anomaly_sensor.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import '../mocks.dart';

void main() {
  group('filterAvailableSensors', () {
    MockSensor sensor({
      required String uuid,
      required String title,
    }) {
      final mock = MockSensor();
      when(() => mock.characteristicUuid).thenReturn(uuid);
      when(() => mock.title).thenReturn(title);
      return mock;
    }

    test('returns empty list when no characteristics match', () {
      final sensors = [
        sensor(
          uuid: TemperatureSensor.sensorCharacteristicUuid,
          title: 'temperature',
        ),
      ];

      expect(filterAvailableSensors(sensors, {}), isEmpty);
    });

    test('includes sensors whose characteristic is on the box', () {
      final temperature = sensor(
        uuid: TemperatureSensor.sensorCharacteristicUuid,
        title: 'temperature',
      );

      final available = filterAvailableSensors(
        [temperature],
        {TemperatureSensor.sensorCharacteristicUuid},
      );

      expect(available, [temperature]);
    });

    test('excludes sensors not present on the box', () {
      final temperature = sensor(
        uuid: TemperatureSensor.sensorCharacteristicUuid,
        title: 'temperature',
      );
      final humidity = sensor(
        uuid: '11111111-2222-3333-4444-555555555555',
        title: 'humidity',
      );

      final available = filterAvailableSensors(
        [temperature, humidity],
        {TemperatureSensor.sensorCharacteristicUuid},
      );

      expect(available, [temperature]);
    });

    test('excludes surface anomaly when feature flag hides it', () {
      FeatureFlags.hideSurfaceAnomalySensor = true;
      final surfaceAnomaly = sensor(
        uuid: SurfaceAnomalySensor.sensorCharacteristicUuid,
        title: 'surface_anomaly',
      );

      expect(
        filterAvailableSensors(
          [surfaceAnomaly],
          {SurfaceAnomalySensor.sensorCharacteristicUuid},
        ),
        isEmpty,
      );
    });

    test('includes surface anomaly when feature flag allows it', () {
      FeatureFlags.hideSurfaceAnomalySensor = false;
      addTearDown(() => FeatureFlags.hideSurfaceAnomalySensor = true);
      final surfaceAnomaly = sensor(
        uuid: SurfaceAnomalySensor.sensorCharacteristicUuid,
        title: 'surface_anomaly',
      );

      final available = filterAvailableSensors(
        [surfaceAnomaly],
        {SurfaceAnomalySensor.sensorCharacteristicUuid},
      );

      expect(available, [surfaceAnomaly]);
    });
  });

  group('sortSensorsByUiPriority', () {
    MockSensor sensor({required int uiPriority}) {
      final mock = MockSensor();
      when(() => mock.uiPriority).thenReturn(uiPriority);
      return mock;
    }

    test('returns empty list for empty input', () {
      expect(sortSensorsByUiPriority([]), isEmpty);
    });

    test('returns single sensor unchanged', () {
      final only = sensor(uiPriority: 3);

      expect(sortSensorsByUiPriority([only]), [only]);
    });

    test('returns sensors ordered by ascending uiPriority', () {
      final low = sensor(uiPriority: 1);
      final high = sensor(uiPriority: 10);
      final mid = sensor(uiPriority: 5);

      expect(
        sortSensorsByUiPriority([high, low, mid]),
        [low, mid, high],
      );
    });

    test('does not mutate the input list', () {
      final low = sensor(uiPriority: 1);
      final high = sensor(uiPriority: 10);
      final input = [high, low];

      sortSensorsByUiPriority(input);

      expect(input, [high, low]);
    });
  });
}
