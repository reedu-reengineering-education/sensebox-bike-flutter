import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import '../../mocks.dart';

void main() {
  late MockIsarService mockIsarService;
  late MockSensorService mockSensorService;

  setUpAll(() {
    // Register a fallback value for SensorData
    registerFallbackValue(FakeSensorData());
  });

  setUp(() {
    mockIsarService = MockIsarService();
    mockSensorService = MockSensorService();

    // Mock the sensorService in IsarService
    when(() => mockIsarService.sensorService).thenReturn(mockSensorService);

    // Mock the saveSensorData method to return a Future<int>
    when(() => mockSensorService.saveSensorData(any()))
        .thenAnswer((_) async => 1);
  });

  test('should store data for SurfaceAnomalySensor when feature flag is enabled', () async {
    // Arrange
    FeatureFlags.hideSurfaceAnomalySensor = true; // Enable the feature flag
    final sensorData = SensorData()
      ..title = 'surface_anomaly'
      ..value = 1.23
      ..attribute = 'anomaly_level';

    // Act
    await mockSensorService.saveSensorData(sensorData);

    // Assert
    final capturedData =
        verify(() => mockSensorService.saveSensorData(captureAny()))
            .captured
            .single as SensorData;

    // Verify the captured data
    expect(capturedData.title, 'surface_anomaly');
    expect(capturedData.value, 1.23);
    expect(capturedData.attribute, 'anomaly_level');
  });
}