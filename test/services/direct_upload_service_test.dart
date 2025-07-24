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
      expect(directUploadService.isEnabled, false);
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

      expect(directUploadService.isEnabled, false);
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
  });
} 