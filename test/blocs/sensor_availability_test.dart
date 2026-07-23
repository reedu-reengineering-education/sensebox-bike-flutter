import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/sensor_availability.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/sensors/surface_anomaly_sensor.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import '../mocks.dart';

MockSensor mockSensor({
  String? uuid,
  String? title,
  int? uiPriority,
}) {
  final mock = MockSensor();
  if (uuid != null) {
    when(() => mock.characteristicUuid).thenReturn(uuid);
  }
  if (title != null) {
    when(() => mock.title).thenReturn(title);
  }
  if (uiPriority != null) {
    when(() => mock.uiPriority).thenReturn(uiPriority);
  }
  return mock;
}

bool alwaysLive(String _) => true;
bool neverLive(String _) => false;

void main() {
  setUp(() {
    FeatureFlags.hideSurfaceAnomalySensor = true;
  });

  group('filterAvailableSensors', () {
    test('returns empty list when no characteristics match', () {
      final sensors = [
        mockSensor(
          uuid: TemperatureSensor.sensorCharacteristicUuid,
          title: 'temperature',
        ),
      ];

      expect(filterAvailableSensors(sensors, {}, neverLive), isEmpty);
    });

    test('includes sensors whose characteristic is on the box and has live data',
        () {
      final temperature = mockSensor(
        uuid: TemperatureSensor.sensorCharacteristicUuid,
        title: 'temperature',
      );

      final available = filterAvailableSensors(
        [temperature],
        {TemperatureSensor.sensorCharacteristicUuid},
        alwaysLive,
      );

      expect(available, [temperature]);
    });

    test('excludes sensors without live payload', () {
      final temperature = mockSensor(
        uuid: TemperatureSensor.sensorCharacteristicUuid,
        title: 'temperature',
      );

      final available = filterAvailableSensors(
        [temperature],
        {TemperatureSensor.sensorCharacteristicUuid},
        neverLive,
      );

      expect(available, isEmpty);
    });

    test('excludes sensors not present on the box', () {
      final temperature = mockSensor(
        uuid: TemperatureSensor.sensorCharacteristicUuid,
        title: 'temperature',
      );
      final humidity = mockSensor(
        uuid: '11111111-2222-3333-4444-555555555555',
        title: 'humidity',
      );

      final available = filterAvailableSensors(
        [temperature, humidity],
        {TemperatureSensor.sensorCharacteristicUuid},
        alwaysLive,
      );

      expect(available, [temperature]);
    });

    test('excludes surface anomaly when feature flag hides it', () {
      final surfaceAnomaly = mockSensor(
        uuid: SurfaceAnomalySensor.sensorCharacteristicUuid,
        title: 'surface_anomaly',
      );

      expect(
        filterAvailableSensors(
          [surfaceAnomaly],
          {SurfaceAnomalySensor.sensorCharacteristicUuid},
          alwaysLive,
        ),
        isEmpty,
      );
    });

    test('includes surface anomaly when feature flag allows it', () {
      FeatureFlags.hideSurfaceAnomalySensor = false;
      final surfaceAnomaly = mockSensor(
        uuid: SurfaceAnomalySensor.sensorCharacteristicUuid,
        title: 'surface_anomaly',
      );

      final available = filterAvailableSensors(
        [surfaceAnomaly],
        {SurfaceAnomalySensor.sensorCharacteristicUuid},
        alwaysLive,
      );

      expect(available, [surfaceAnomaly]);
    });
  });

  group('filterDiscoveredSensors', () {
    test('includes sensors with discovered characteristics regardless of payload',
        () {
      final temperature = mockSensor(
        uuid: TemperatureSensor.sensorCharacteristicUuid,
        title: 'temperature',
      );

      final discovered = filterDiscoveredSensors(
        [temperature],
        {TemperatureSensor.sensorCharacteristicUuid},
      );

      expect(discovered, [temperature]);
    });
  });

  group('sortSensorsByUiPriority', () {
    test('returns sensors ordered by ascending uiPriority', () {
      final low = mockSensor(uiPriority: 1);
      final high = mockSensor(uiPriority: 10);
      final mid = mockSensor(uiPriority: 5);

      expect(
        sortSensorsByUiPriority([high, low, mid]),
        [low, mid, high],
      );
    });

    test('does not mutate the input list', () {
      final low = mockSensor(uiPriority: 1);
      final high = mockSensor(uiPriority: 10);
      final input = [high, low];

      sortSensorsByUiPriority(input);

      expect(input, [high, low]);
    });
  });
}
