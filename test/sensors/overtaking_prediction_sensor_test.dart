import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/sensors/overtaking_prediction_sensor.dart';
import '../mocks.dart';

void main() {
  late MockBleBloc mockBleBloc;
  late MockGeolocationBloc mockGeolocationBloc;
  late MockRecordingBloc mockRecordingBloc;
  late MockSettingsBloc mockSettingsBloc;
  late MockIsarService mockIsarService;

  setUp(() {
    mockBleBloc = MockBleBloc();
    mockGeolocationBloc = MockGeolocationBloc();
    mockRecordingBloc = MockRecordingBloc();
    mockSettingsBloc = MockSettingsBloc();
    mockIsarService = MockIsarService();
  });

  group('OvertakingPredictionSensor', () {
    test('aggregateData returns the max value from array of values', () {
      // Arrange
      final sensor = OvertakingPredictionSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [0.3],
        [0.5],
        [0.8],
        [0.2],
        [0.9],
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(0.9)); // Should return max value
    });

    test('aggregateData handles empty buffer', () {
      // Arrange
      final sensor = OvertakingPredictionSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = <List<double>>[];

      // Act & Assert
      expect(
        () => sensor.aggregateData(valueBuffer),
        throwsStateError,
      );
    });

    test('aggregateData handles single value', () {
      // Arrange
      final sensor = OvertakingPredictionSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [0.75],
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(0.75));
    });

    test('aggregateData returns max even when all values are the same', () {
      // Arrange
      final sensor = OvertakingPredictionSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [0.5],
        [0.5],
        [0.5],
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(0.5));
    });

    test('aggregateData handles zero and boundary values', () {
      // Arrange
      final sensor = OvertakingPredictionSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [0.0],
        [0.1],
        [1.0],
        [0.5],
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(1.0)); // Should return max value
    });

    test('aggregateData handles very small differences', () {
      // Arrange
      final sensor = OvertakingPredictionSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [0.123456],
        [0.123457],
        [0.123455],
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(0.123457)); // Should return max value
    });
  });
}
