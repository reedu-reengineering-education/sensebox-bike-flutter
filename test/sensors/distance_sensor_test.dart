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
    test(
        'aggregateData returns the min value from array of values (excluding zeros)',
        () {
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
      expect(result[0], equals(2.5)); // Should return min value
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

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(0.0)); // Should return zero for empty buffer
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
      expect(result[0], equals(2.0)); // Min distance
    });

    test(
        'aggregateData excludes zero values and returns min of non-zero values',
        () {
      // Arrange
      final sensor = DistanceSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [0.0], // 0cm (should be excluded)
        [5.0], // 5cm
        [0.0], // 0cm (should be excluded)
        [3.0], // 3cm
        [8.0], // 8cm
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(3.0)); // Min of non-zero values
    });

    test('aggregateData returns zero when all values are zero', () {
      // Arrange
      final sensor = DistanceSensor(
        mockBleBloc,
        mockGeolocationBloc,
        mockRecordingBloc,
        mockSettingsBloc,
        mockIsarService,
      );

      final valueBuffer = [
        [0.0],
        [0.0],
        [0.0],
      ];

      // Act
      final result = sensor.aggregateData(valueBuffer);

      // Assert
      expect(result, isA<List<double>>());
      expect(result.length, equals(1));
      expect(result[0], equals(0.0)); // Should return zero
    });
  });
}
