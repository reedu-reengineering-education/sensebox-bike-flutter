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

    tearDown(() {
      directUploadService.dispose();
    });

    // Core functionality tests that actually work
    test('adds data to accumulated sensor data', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [22.5]
        },
      };

      // Add data
      final result =
          directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
      
      expect(result, true);
      expect(directUploadService.hasPreservedData, true);
    });
    test('returns false when service is disabled', () async {
      // Start with disabled service
      expect(directUploadService.isEnabled, false);

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [22.5]
        },
      };

      // Should return false when service is disabled
      final result =
          directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
      expect(result, false);
    });

    test('can be re-enabled after being disabled', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Disable the service
      directUploadService.disable();
      expect(directUploadService.isEnabled, false);

      // Re-enable the service
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);
    });

    test('remains enabled after network timeout error',
        () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

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
      expect(directUploadService.hasPreservedData, true);

      // Setup mock to throw network error - should be handled by OpenSenseMapService
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
          .thenThrow(Exception('Network timeout'));

      await directUploadService.uploadRemainingBufferedData();
      // Service should remain enabled because network timeouts are handled by OpenSenseMapService
      expect(directUploadService.isEnabled, true);
      expect(directUploadService.hasPreservedData, false);
    });



    test(
        'remains enabled after temporary authentication errors',
        () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to throw temporary authentication error
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
      
      // Service should remain enabled because temporary auth errors are handled by OpenSenseMap service
      expect(directUploadService.isEnabled, true);
    });

    test(
        'disables service for permanent authentication failures - no refresh token',
        () async {
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

      // Service should be disabled for permanent authentication failures
      expect(directUploadService.isEnabled, false);
    });

    test(
        'disables service for permanent authentication failures - user needs re-login',
        () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Test with "Authentication failed - user needs to re-login" error
      when(() => mockOpenSenseMapService.uploadData(any(), any())).thenThrow(
          Exception('Authentication failed - user needs to re-login'));

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

      // Service should be disabled for permanent authentication failures
      expect(directUploadService.isEnabled, false);
    });

    test(
        'disables service for client errors - forbidden access',
        () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Test with "403 Forbidden" error - should be treated as client error
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
          .thenThrow(Exception('Client error 403: Forbidden'));

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

      // Service should be disabled for client errors (4xx)
      expect(directUploadService.isEnabled, false);
    });

    test(
        'disables service for permanent authentication failures - failed token refresh',
        () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Test with "Failed to refresh token" error
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
          .thenThrow(Exception('Failed to refresh token: Network error'));

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

      // Service should be disabled for permanent authentication failures
      expect(directUploadService.isEnabled, false);
    });

    test('remains enabled after temporary server errors', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to throw temporary server error
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
          .thenThrow(Exception('Server error 503 - retrying'));

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

      // Service should remain enabled because temporary server errors are handled by OpenSenseMap service
      expect(directUploadService.isEnabled, true);
    });

    test('remains enabled after rate limiting errors', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to throw rate limiting error
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
          .thenThrow(Exception('TooManyRequestsException'));

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

      // Service should remain enabled because rate limiting errors are handled by OpenSenseMap service
      expect(directUploadService.isEnabled, true);
    });

    test('remains enabled after successful upload', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to succeed
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
          .thenAnswer((_) async {});

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

      // Service should remain enabled after successful upload
      expect(directUploadService.isEnabled, true);
    });
  });
} 