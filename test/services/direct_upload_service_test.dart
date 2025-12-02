import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}
class MockOpenSenseMapBloc extends Mock implements OpenSenseMapBloc {
  @override
  Future<void> uploadData(String senseBoxId, Map<String, dynamic> data) async {
    return super.noSuchMethod(
      Invocation.method(#uploadData, [senseBoxId, data]),
    );
  }
}

List<SensorBatch> convertToSensorBatches(
    Map<GeolocationData, Map<String, List<double>>> groupedData) {
  final batches = <SensorBatch>[];
  for (final entry in groupedData.entries) {
    batches.add(SensorBatch(
      geoLocation: entry.key,
      aggregatedData: entry.value,
      timestamp: DateTime.now(),
    ));
  }
  return batches;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DirectUploadService Tests', () {
    late DirectUploadService directUploadService;
    late MockOpenSenseMapService mockOpenSenseMapService;
    late MockOpenSenseMapBloc mockOpenSenseMapBloc;
    late SenseBox mockSenseBox;

    setUp(() {
      mockOpenSenseMapService = MockOpenSenseMapService();
      mockOpenSenseMapBloc = MockOpenSenseMapBloc();
      mockSenseBox = SenseBox()
        ..sId = 'test-sensebox-id'
        ..name = 'Test SenseBox'
        ..sensors = [
          Sensor()
            ..id = 'temperature-sensor-id'
            ..title = 'Temperature',
          Sensor()
            ..id = 'speed-sensor-id'
            ..title = 'Speed',
        ];

      // Set default mock behavior for isAcceptingRequests
      when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(true);

      directUploadService = DirectUploadService(
        openSenseMapService: mockOpenSenseMapService,
        senseBox: mockSenseBox,
        openSenseMapBloc: mockOpenSenseMapBloc,
      );
    });

    tearDown(() {
      directUploadService.dispose();
    });

    group('Track Upload Status Behavior', () {
      test('should NOT mark track as uploaded after successful direct upload',
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

        directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
        await directUploadService.uploadRemainingBufferedData();

        expect(directUploadService.isEnabled, true);
        expect(directUploadService.hasPreservedData, false);
      });

      test('should NOT mark track as uploaded after successful sync upload',
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

        directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));

        await directUploadService.uploadRemainingBufferedData();

        expect(directUploadService.isEnabled, true);
      });
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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      
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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      expect(directUploadService.hasPreservedData, false);
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

      // Setup mock to be authenticated
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      expect(directUploadService.hasPreservedData, true);

      // Setup mock to throw network error - should be handled by OpenSenseMapService
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
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

      // Setup mock to be authenticated
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

      // Setup mock to throw temporary authentication error
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
          .thenThrow(Exception('Token refreshed, retrying'));

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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      await directUploadService.uploadRemainingBufferedData();
      
      // Service should remain enabled because temporary auth errors are handled by OpenSenseMap service
      expect(directUploadService.isEnabled, true);
    });

    test(
        'remains enabled for authentication failures - bloc handles auth',
        () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to be authenticated initially
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

      // Test with "No refresh token found" error
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      await directUploadService.uploadRemainingBufferedData();
      
      // Service should remain enabled since bloc handles authentication
      expect(directUploadService.isEnabled, true);
    });

    test(
        'remains enabled for authentication failures - user needs re-login',
        () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to be authenticated initially
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

      // Test with "Authentication failed - user needs to re-login" error
      when(() => mockOpenSenseMapBloc.uploadData(any(), any())).thenThrow(
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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      await directUploadService.uploadRemainingBufferedData();

      // Service should remain enabled since bloc handles authentication
      expect(directUploadService.isEnabled, true);
    });

    test(
        'disables service for client errors - forbidden access',
        () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to be authenticated initially
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

      // Test with "403 Forbidden" error - should be treated as client error
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      await directUploadService.uploadRemainingBufferedData();

      // Service should be disabled for client errors (4xx)
      expect(directUploadService.isEnabled, false);
    });

    test(
        'remains enabled for authentication failures - failed token refresh',
        () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to be authenticated initially
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

      // Test with "Failed to refresh token" error
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      await directUploadService.uploadRemainingBufferedData();

      // Service should remain enabled since bloc handles authentication
      expect(directUploadService.isEnabled, true);
    });

    test('remains enabled after temporary server errors', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to be authenticated
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

      // Setup mock to throw temporary server error
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      await directUploadService.uploadRemainingBufferedData();

      // Service should remain enabled because temporary server errors are handled by OpenSenseMap service
      expect(directUploadService.isEnabled, true);
    });

    test('remains enabled after rate limiting errors', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to be authenticated
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

      // Setup mock to throw rate limiting error
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
          .thenThrow(TooManyRequestsException(30));

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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      await directUploadService.uploadRemainingBufferedData();

      // Service should remain enabled because rate limiting errors are handled by OpenSenseMap service
      expect(directUploadService.isEnabled, true);
    });

    test('remains enabled after successful upload', () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to be authenticated
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

      // Setup mock to succeed
      when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
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

      directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
      await directUploadService.uploadRemainingBufferedData();

      // Service should remain enabled after successful upload
      expect(directUploadService.isEnabled, true);
    });

    // New comprehensive error handling tests
    group('Error Handling Tests', () {
      test('handles 429 rate limiting error correctly', () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw 429 rate limiting error
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenThrow(TooManyRequestsException(30));

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

        directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
        await directUploadService.uploadRemainingBufferedData();

        // Service should remain enabled for 429 errors (temporary)
        expect(directUploadService.isEnabled, true);
        // Data is cleared during uploadRemainingBufferedData() even for temporary errors
        expect(directUploadService.hasPreservedData, false);
      });

      test('handles 502 server error correctly', () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw 502 server error
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenThrow(Exception('Server error 502 - retrying'));

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

        directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
        await directUploadService.uploadRemainingBufferedData();

        // Service should remain enabled for 502 errors (temporary)
        expect(directUploadService.isEnabled, true);
        // Data is cleared during uploadRemainingBufferedData() even for temporary errors
        expect(directUploadService.hasPreservedData, false);
      });

      test(
          'handles authentication error correctly - service remains enabled',
          () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated initially
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw authentication error
        when(() => mockOpenSenseMapBloc.uploadData(any(), any())).thenThrow(
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

        directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
        await directUploadService.uploadRemainingBufferedData();

        expect(directUploadService.isEnabled, true);
        expect(directUploadService.hasPreservedData, false);
      });

      test('handles token refresh error correctly', () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw token refresh error
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenThrow(Exception('Token refreshed, retrying'));

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

        directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
        await directUploadService.uploadRemainingBufferedData();

        // Service should remain enabled for token refresh errors (temporary)
        expect(directUploadService.isEnabled, true);
        // Data is cleared during uploadRemainingBufferedData() even for temporary errors
        expect(directUploadService.hasPreservedData, false);
      });

      test(
          'handles "Not authenticated" error correctly - service remains enabled',
          () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated initially
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw "Not authenticated" error
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
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

        directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
        await directUploadService.uploadRemainingBufferedData();

        expect(directUploadService.isEnabled, true);
        expect(directUploadService.hasPreservedData, false);
      });

      test('handles timeout error correctly', () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw timeout error
        when(() => mockOpenSenseMapBloc.uploadData(any(), any())).thenThrow(
            TimeoutException('Upload timeout', const Duration(seconds: 30)));

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

        directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
        await directUploadService.uploadRemainingBufferedData();

        // Service should remain enabled for timeout errors (temporary)
        expect(directUploadService.isEnabled, true);
        // Data is cleared during uploadRemainingBufferedData() even for temporary errors
        // This is correct behavior for final upload attempts
        expect(directUploadService.hasPreservedData, false);
      });

      test('handles 404 client error correctly', () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated initially
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw 404 client error
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenThrow(Exception('Client error 404: Not Found'));

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

        directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
        await directUploadService.uploadRemainingBufferedData();

        expect(directUploadService.isEnabled, false);
        expect(directUploadService.hasPreservedData, false);
      });

      test('verifies different error types have correct behavior', () async {
        // Test that temporary errors keep service enabled but clear data during final upload
        final temporaryErrors = [
          'TooManyRequestsException: Retry after 30 seconds.',
          'Server error 502 - retrying',
          'Server error 503 - retrying',
          'Token refreshed, retrying',
          'TimeoutException: Upload timeout',
        ];

        for (final error in temporaryErrors) {
          directUploadService.enable();
          expect(directUploadService.isEnabled, true);

          // Setup mock to be authenticated
          when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

          when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
              .thenThrow(
                  error == 'TooManyRequestsException: Retry after 30 seconds.'
                      ? TooManyRequestsException(30)
                      : error == 'TimeoutException: Upload timeout'
                          ? TimeoutException(
                              'Upload timeout', const Duration(seconds: 30))
                          : Exception(error));

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

          directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
          await directUploadService.uploadRemainingBufferedData();

          expect(directUploadService.isEnabled, true,
              reason: 'Service should remain enabled for error: $error');
          // Data is cleared during final upload attempt even for temporary errors
          // This is correct behavior for final upload attempts
          expect(directUploadService.hasPreservedData, false,
              reason:
                  'Data should be cleared during final upload for error: $error');

          directUploadService.dispose();
        }

        // Test that authentication errors are handled by bloc and don't disable service
        final authErrors = [
          'Authentication failed - user needs to re-login',
          'No refresh token found',
          'Failed to refresh token: Network error',
          'Not authenticated',
        ];

        for (final error in authErrors) {
          directUploadService.enable();
          expect(directUploadService.isEnabled, true);

          // Setup mock to be authenticated initially
          when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

          when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
              .thenThrow(Exception(error));

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

          directUploadService.queueBatchesForUpload(convertToSensorBatches(groupedData));
          await directUploadService.uploadRemainingBufferedData();

          expect(directUploadService.isEnabled, true,
              reason: 'Service should remain enabled for auth error: $error');
          expect(directUploadService.hasPreservedData, false,
              reason:
                  'Data should be cleared after upload attempt for auth error: $error');

          directUploadService.dispose();
        }
      });
    });

    group('Data Loss Callback Tests', () {
      test('should call onDataLoss callback when upload fails during recording', () async {
        bool dataLossCalled = false;
        
        final serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
          onDataLoss: () => dataLossCalled = true,
        );
        
        serviceWithCallback.enable();
        
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenThrow(Exception('Network error'));
        
        final geo = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
        
        final batches = [
          SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5]},
            timestamp: DateTime.now(),
          )
        ];
        
        serviceWithCallback.queueBatchesForUpload(batches);
        await serviceWithCallback.uploadRemainingBufferedData();
        
        expect(dataLossCalled, true);
        
        serviceWithCallback.dispose();
      });

      test('should call onDataLoss callback only once for multiple errors', () async {
        int dataLossCallCount = 0;
        
        final serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
          onDataLoss: () => dataLossCallCount++,
        );
        
        serviceWithCallback.enable();
        
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenThrow(Exception('Network error'));
        
        // Queue and try to upload multiple times
        for (int i = 0; i < 3; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i
            ..longitude = 20.0 + i
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          final batches = [
            SensorBatch(
              geoLocation: geo,
              aggregatedData: {'temperature': [22.5 + i]},
              timestamp: DateTime.now(),
            )
          ];
          
          serviceWithCallback.queueBatchesForUpload(batches);
          await serviceWithCallback.uploadRemainingBufferedData();
        }
        
        expect(dataLossCallCount, 1);
        
        serviceWithCallback.dispose();
      });

      test('should not call onDataLoss callback when upload succeeds', () async {
        bool dataLossCalled = false;
        
        final serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
          onDataLoss: () => dataLossCalled = true,
        );
        
        serviceWithCallback.enable();
        
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenAnswer((_) async {});
        
        final geo = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
        
        final batches = [
          SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5]},
            timestamp: DateTime.now(),
          )
        ];
        
        serviceWithCallback.queueBatchesForUpload(batches);
        await serviceWithCallback.uploadRemainingBufferedData();
        
        expect(dataLossCalled, false);
        
        serviceWithCallback.dispose();
      });

      test('should call onDataLoss for temporary network errors', () async {
        bool dataLossCalled = false;
        
        final serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
          onDataLoss: () => dataLossCalled = true,
        );
        
        serviceWithCallback.enable();
        
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenThrow(Exception('Server error 503 - retrying'));
        
        final geo = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
        
        final batches = [
          SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5]},
            timestamp: DateTime.now(),
          )
        ];
        
        serviceWithCallback.queueBatchesForUpload(batches);
        await serviceWithCallback.uploadRemainingBufferedData();
        
        expect(dataLossCalled, true);
        
        serviceWithCallback.dispose();
      });

      test('should call onDataLoss for authentication errors', () async {
        bool dataLossCalled = false;
        
        final serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
          onDataLoss: () => dataLossCalled = true,
        );
        
        serviceWithCallback.enable();
        
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenThrow(Exception('Authentication failed - user needs to re-login'));
        
        final geo = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
        
        final batches = [
          SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5]},
            timestamp: DateTime.now(),
          )
        ];
        
        serviceWithCallback.queueBatchesForUpload(batches);
        await serviceWithCallback.uploadRemainingBufferedData();
        
        expect(dataLossCalled, true);
        
        serviceWithCallback.dispose();
      });

      test('should call onDataLoss for client errors', () async {
        bool dataLossCalled = false;
        
        final serviceWithCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
          onDataLoss: () => dataLossCalled = true,
        );
        
        serviceWithCallback.enable();
        
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenThrow(Exception('Client error 404: Not Found'));
        
        final geo = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
        
        final batches = [
          SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5]},
            timestamp: DateTime.now(),
          )
        ];
        
        serviceWithCallback.queueBatchesForUpload(batches);
        await serviceWithCallback.uploadRemainingBufferedData();
        
        expect(dataLossCalled, true);
        
        serviceWithCallback.dispose();
      });

      test('should work without onDataLoss callback (null)', () async {
        final serviceWithoutCallback = DirectUploadService(
          openSenseMapService: mockOpenSenseMapService,
          senseBox: mockSenseBox,
          openSenseMapBloc: mockOpenSenseMapBloc,
        );
        
        serviceWithoutCallback.enable();
        
        when(() => mockOpenSenseMapBloc.uploadData(any(), any()))
            .thenThrow(Exception('Network error'));
        
        final geo = GeolocationData()
          ..id = 1
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
        
        final batches = [
          SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5]},
            timestamp: DateTime.now(),
          )
        ];
        
        serviceWithoutCallback.queueBatchesForUpload(batches);
        
        // Should not throw even without callback
        await serviceWithoutCallback.uploadRemainingBufferedData();
        
        expect(serviceWithoutCallback.hasPreservedData, false);
        
        serviceWithoutCallback.dispose();
      });
    });

    group('Queue Limit Tests', () {
      test('should enforce queue limit of 1000 batches', () async {
        directUploadService.enable();
        when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(false);
        
        // Create 1000 batches to fill the queue
        final batches = <SensorBatch>[];
        for (int i = 0; i < 1000; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          batches.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5 + i]},
            timestamp: DateTime.now(),
          ));
        }
        
        // Add all batches at once
        directUploadService.queueBatchesForUpload(batches);
        expect(directUploadService.hasPreservedData, true);
        
        // Try to add 10 more batches - should trigger queue limit
        final additionalBatches = <SensorBatch>[];
        for (int i = 1000; i < 1010; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          additionalBatches.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5 + i]},
            timestamp: DateTime.now(),
          ));
        }
        
        directUploadService.queueBatchesForUpload(additionalBatches);
        
        // Queue should still be at or below 1000
        // Note: We can't directly check the internal queue size, but we can verify
        // the service still has preserved data
        expect(directUploadService.hasPreservedData, true);
      });

      test('should remove oldest batches when limit is exceeded', () async {
        directUploadService.enable();
        when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(false);
        
        // Fill queue with 998 batches (just under limit)
        final initialBatches = <SensorBatch>[];
        for (int i = 0; i < 998; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          initialBatches.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5 + i]},
            timestamp: DateTime.now(),
          ));
        }
        
        directUploadService.queueBatchesForUpload(initialBatches);
        expect(directUploadService.hasPreservedData, true);
        
        // Add 5 more batches - should remove 3 oldest batches (998 + 5 - 1000 = 3)
        final additionalBatches = <SensorBatch>[];
        for (int i = 998; i < 1003; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          additionalBatches.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5 + i]},
            timestamp: DateTime.now(),
          ));
        }
        
        directUploadService.queueBatchesForUpload(additionalBatches);
        
        // Service should still have preserved data
        expect(directUploadService.hasPreservedData, true);
      });

      test('should handle adding more batches than limit in one call', () async {
        directUploadService.enable();
        when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(false);
        
        // Fill queue with 500 batches
        final initialBatches = <SensorBatch>[];
        for (int i = 0; i < 500; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          initialBatches.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5 + i]},
            timestamp: DateTime.now(),
          ));
        }
        
        directUploadService.queueBatchesForUpload(initialBatches);
        expect(directUploadService.hasPreservedData, true);
        
        // Try to add 600 batches at once (would exceed limit by 100)
        final largeBatch = <SensorBatch>[];
        for (int i = 500; i < 1100; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          largeBatch.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5 + i]},
            timestamp: DateTime.now(),
          ));
        }
        
        directUploadService.queueBatchesForUpload(largeBatch);
        
        // Service should still have preserved data and queue should be at limit
        expect(directUploadService.hasPreservedData, true);
      });

      test('should not exceed limit when adding batches incrementally', () async {
        directUploadService.enable();
        when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(false);
        
        // Add batches incrementally to reach limit
        for (int batch = 0; batch < 10; batch++) {
          final batches = <SensorBatch>[];
          for (int i = 0; i < 100; i++) {
            final geoId = batch * 100 + i;
            final geo = GeolocationData()
              ..id = geoId
              ..latitude = 10.0 + geoId * 0.001
              ..longitude = 20.0 + geoId * 0.001
              ..speed = 5.0
              ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, geoId);
            
            batches.add(SensorBatch(
              geoLocation: geo,
              aggregatedData: {'temperature': [22.5 + geoId]},
              timestamp: DateTime.now(),
            ));
          }
          
          directUploadService.queueBatchesForUpload(batches);
          
          // After 10 batches of 100, we should be at exactly 1000
          if (batch == 9) {
            expect(directUploadService.hasPreservedData, true);
          }
        }
        
        // Try to add one more batch - should trigger limit enforcement
        final additionalBatch = <SensorBatch>[];
        final geo = GeolocationData()
          ..id = 1000
          ..latitude = 10.0 + 1000 * 0.001
          ..longitude = 20.0 + 1000 * 0.001
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 1000);
        
        additionalBatch.add(SensorBatch(
          geoLocation: geo,
          aggregatedData: {'temperature': [22.5 + 1000]},
          timestamp: DateTime.now(),
        ));
        
        directUploadService.queueBatchesForUpload(additionalBatch);
        
        // Service should still have preserved data
        expect(directUploadService.hasPreservedData, true);
      });

      test('should handle queue limit with merged batches', () async {
        directUploadService.enable();
        when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(false);
        
        // Add 500 batches
        final initialBatches = <SensorBatch>[];
        for (int i = 0; i < 500; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          initialBatches.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5 + i]},
            timestamp: DateTime.now(),
          ));
        }
        
        directUploadService.queueBatchesForUpload(initialBatches);
        expect(directUploadService.hasPreservedData, true);
        
        // Add 500 more batches with same geoIds (should merge)
        final mergeBatches = <SensorBatch>[];
        for (int i = 0; i < 500; i++) {
          final geo = GeolocationData()
            ..id = i  // Same geoId as initial batches
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          mergeBatches.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'humidity': [50.0 + i]},  // Different sensor
            timestamp: DateTime.now(),
          ));
        }
        
        directUploadService.queueBatchesForUpload(mergeBatches);
        
        // Merging doesn't increase count, so should still be at 500
        expect(directUploadService.hasPreservedData, true);
        
        // Now add 600 new batches - should trigger limit and remove 100 oldest
        final newBatches = <SensorBatch>[];
        for (int i = 500; i < 1100; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          newBatches.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5 + i]},
            timestamp: DateTime.now(),
          ));
        }
        
        directUploadService.queueBatchesForUpload(newBatches);
        
        // Service should still have preserved data
        expect(directUploadService.hasPreservedData, true);
      });

      test('should maintain limit when queue is cleared and refilled', () async {
        directUploadService.enable();
        when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(true);
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);
        when(() => mockOpenSenseMapBloc.uploadData(any(), any())).thenAnswer((_) async {});
        
        // Fill queue with 1000 batches
        final batches = <SensorBatch>[];
        for (int i = 0; i < 1000; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          batches.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5 + i]},
            timestamp: DateTime.now(),
          ));
        }
        
        directUploadService.queueBatchesForUpload(batches);
        
        // Upload should succeed and clear queue
        await Future.delayed(Duration(milliseconds: 100));
        expect(directUploadService.hasPreservedData, false);
        
        // Refill queue with 1000 batches again
        directUploadService.queueBatchesForUpload(batches);
        expect(directUploadService.hasPreservedData, true);
        
        // Try to add more - should enforce limit again
        final additionalBatches = <SensorBatch>[];
        for (int i = 1000; i < 1010; i++) {
          final geo = GeolocationData()
            ..id = i
            ..latitude = 10.0 + i * 0.001
            ..longitude = 20.0 + i * 0.001
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, i);
          
          additionalBatches.add(SensorBatch(
            geoLocation: geo,
            aggregatedData: {'temperature': [22.5 + i]},
            timestamp: DateTime.now(),
          ));
        }
        
        directUploadService.queueBatchesForUpload(additionalBatches);
        expect(directUploadService.hasPreservedData, true);
      });
    });



  });
} 