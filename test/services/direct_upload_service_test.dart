import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}
class MockSettingsBloc extends Mock implements SettingsBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('DirectUploadService Tests', () {
    late DirectUploadService directUploadService;
    late MockOpenSenseMapService mockOpenSenseMapService;
    late MockSettingsBloc mockSettingsBloc;
    late SenseBox mockSenseBox;

    setUp(() {
      mockOpenSenseMapService = MockOpenSenseMapService();
      mockSettingsBloc = MockSettingsBloc();
      
      mockSenseBox = SenseBox(
        sId: 'test-sensebox-id',
        sensors: [
          Sensor()
            ..id = 'temp-sensor-id'
            ..title = 'Temperature',
          Sensor()
            ..id = 'speed-sensor-id'
            ..title = 'Speed',
        ],
      );

      directUploadService = DirectUploadService(
        openSenseMapService: mockOpenSenseMapService,
        settingsBloc: mockSettingsBloc,
        senseBox: mockSenseBox,
      );
    });

    test('handles authentication errors gracefully', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to throw authentication error
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
          .thenThrow(Exception('Not authenticated'));

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [22.5],
        },
      };

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
      await directUploadService.uploadRemainingBufferedData();
      // Service should remain enabled because OpenSenseMapService handles token refresh
      expect(directUploadService.isEnabled, true);
    });

    test('handles 401 errors gracefully', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
          .thenThrow(Exception('401 Unauthorized'));

      // Create test data
      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [22.5],
        },
      };

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
      await directUploadService.uploadRemainingBufferedData();

      // Service should remain enabled because OpenSenseMapService handles token refresh
      expect(directUploadService.isEnabled, true);
    });

    test('continues to work normally for non-authentication errors', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      when(() => mockOpenSenseMapService.uploadData(any(), any()))
          .thenThrow(Exception('Network timeout'));

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [22.5],
        },
      };

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
      await directUploadService.uploadRemainingBufferedData();

      // Verify that the service remains enabled for non-authentication errors
      expect(directUploadService.isEnabled, true);
    });

    test('disables service for true authentication failures', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Test with "No refresh token found" error
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
          .thenThrow(Exception('No refresh token found'));

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [22.5],
        },
      };

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
      await directUploadService.uploadRemainingBufferedData();

      // Service should be disabled for true authentication failures
      expect(directUploadService.isEnabled, false);
    });

    test('disables service for failed token refresh', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Test with "Failed to refresh token" error
      when(() => mockOpenSenseMapService.uploadData(any(), any())).thenThrow(
          Exception('Failed to refresh token: Invalid refresh token'));

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [22.5],
        },
      };

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
      await directUploadService.uploadRemainingBufferedData();

      // Service should be disabled for failed token refresh
      expect(directUploadService.isEnabled, false);
    });
  });
} 