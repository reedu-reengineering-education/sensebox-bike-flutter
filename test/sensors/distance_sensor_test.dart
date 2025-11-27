import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/sensors/distance_sensor.dart';
import '../mocks.dart';

void main() {
  late DistanceSensor sensor;

  setUp(() {
    sensor = DistanceSensor(
      MockBleBloc(),
      MockGeolocationBloc(),
      MockRecordingBloc(),
      MockIsarService(),
    );
  });

  group('DistanceSensor', () {
    test('uiPriority returns 30', () {
      expect(sensor.uiPriority, 30);
    });

    test('sensorCharacteristicUuid is correct', () {
      expect(
        DistanceSensor.sensorCharacteristicUuid,
        'b3491b60-c0f3-4306-a30d-49c91f37a62b',
      );
    });

    test('lookbackWindow returns 2000ms', () {
      expect(sensor.lookbackWindow, const Duration(milliseconds: 2000));
    });

    test('aggregateData returns min non-zero value from buffer', () {
      final result = sensor.aggregateData([
        [10.0],
        [5.0],
        [20.0],
        [2.5],
      ]);

      expect(result, [2.5]);
    });

    test('aggregateData excludes zeros and returns min of remaining', () {
      final result = sensor.aggregateData([
        [0.0],
        [5.0],
        [0.0],
        [3.0],
        [8.0],
      ]);

      expect(result, [3.0]);
    });

    test('aggregateData returns zero for empty buffer', () {
      expect(sensor.aggregateData([]), [0.0]);
    });

    test('aggregateData returns zero when all values are zero', () {
      final result = sensor.aggregateData([
        [0.0],
        [0.0],
        [0.0],
      ]);

      expect(result, [0.0]);
    });

    test('aggregateData handles single value', () {
      expect(
          sensor.aggregateData([
            [12.5]
          ]),
          [12.5]);
    });
  });
}
