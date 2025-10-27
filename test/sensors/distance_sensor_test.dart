import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/sensors/distance_sensor.dart';
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

  group('DistanceSensor', () {
    test('aggregateData returns the max value from array of values', () {
      // Arrange
      final sensor = DistanceSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [10.0],   // 10cm
        [5.0],    // 5cm
        [20.0],   // 20cm
        [15.0],   // 15cm
        [2.5],    // 2.5cm
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(20.0)); // Should return max value
    });

    test('aggregateData handles empty buffer', () {
      // Arrange
      final sensor = DistanceSensor(
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
      final sensor = DistanceSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [12.5],   // 12.5cm
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(12.5));
    });

    test('aggregateData returns max even when all values are the same', () {
      // Arrange
      final sensor = DistanceSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [8.0],   // 8cm
        [8.0],   // 8cm
        [8.0],   // 8cm
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(8.0));
    });

    test('aggregateData handles realistic distance values', () {
      // Arrange
      final sensor = DistanceSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [5.0],    // 5cm
        [15.0],   // 15cm
        [2.0],    // 2cm
        [25.0],   // 25cm
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(25.0)); // Max distance
    });
  });
}
