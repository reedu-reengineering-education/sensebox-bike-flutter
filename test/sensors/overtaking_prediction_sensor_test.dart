import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/sensors/overtaking_prediction_sensor.dart';
import '../mocks.dart';

void main() {
  late OvertakingPredictionSensor sensor;

  setUp(() {
    sensor = OvertakingPredictionSensor(
      MockBleBloc(),
      MockGeolocationBloc(),
      MockRecordingBloc(),
      MockIsarService(),
    );
  });

  group('OvertakingPredictionSensor', () {
    test('uiPriority returns 40', () {
      expect(sensor.uiPriority, 40);
    });

    test('sensorCharacteristicUuid is correct', () {
      expect(
        OvertakingPredictionSensor.sensorCharacteristicUuid,
        'fc01c688-2c44-4965-ae18-373af9fed18d',
      );
    });

    test('lookbackWindow returns 2000ms', () {
      expect(sensor.lookbackWindow, const Duration(milliseconds: 2000));
    });

    test('aggregateData returns max value from buffer', () {
      final result = sensor.aggregateData([
        [0.3],
        [0.9],
        [0.5],
        [0.2],
      ]);

      expect(result, [0.9]);
    });

    test('aggregateData handles boundary values 0.0 and 1.0', () {
      final result = sensor.aggregateData([
        [0.0],
        [0.5],
        [1.0],
      ]);

      expect(result, [1.0]);
    });

    test('aggregateData returns zero for empty buffer', () {
      expect(sensor.aggregateData([]), [0.0]);
    });

    test('aggregateData handles single value', () {
      expect(sensor.aggregateData([[0.75]]), [0.75]);
    });

    test('aggregateData handles empty inner lists', () {
      final result = sensor.aggregateData([
        [],
        [0.5],
        [],
      ]);

      expect(result, [0.5]);
    });
  });
}
