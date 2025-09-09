import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}
class MockSettingsBloc extends Mock implements SettingsBloc {}
class MockOpenSenseMapBloc extends Mock implements OpenSenseMapBloc {
  @override
  Future<void> uploadData(String senseBoxId, Map<String, dynamic> data) async {
    return super.noSuchMethod(
      Invocation.method(#uploadData, [senseBoxId, data]),
    );
  }
}
class MockTrackService extends Mock implements TrackService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('UploadErrorClassifier Tests', () {
    group('classifyError', () {
      test('classifies permanent authentication errors correctly', () {
        final authErrors = [
          'Authentication failed - user needs to re-login',
          'No refresh token found',
          'Failed to refresh token: Network error',
          'Not authenticated',
        ];

        for (final error in authErrors) {
          final result = UploadErrorClassifier.classifyError(Exception(error));
          expect(result, equals(UploadErrorType.permanentAuth),
              reason: 'Should classify "$error" as permanent auth error');
        }
      });

      test('classifies temporary errors correctly', () {
        final temporaryErrors = [
          'Server error 502 - retrying',
          'Server error 503 - retrying',
          'Token refreshed, retrying',
        ];

        for (final error in temporaryErrors) {
          final result = UploadErrorClassifier.classifyError(Exception(error));
          expect(result, equals(UploadErrorType.temporary),
              reason: 'Should classify "$error" as temporary error');
        }
      });

      test('classifies exception types correctly', () {
        final temporaryExceptions = [
          TooManyRequestsException(30),
          TimeoutException('Upload timeout', const Duration(seconds: 30)),
        ];

        for (final exception in temporaryExceptions) {
          final result = UploadErrorClassifier.classifyError(exception);
          expect(result, equals(UploadErrorType.temporary),
              reason:
                  'Should classify ${exception.runtimeType} as temporary error');
        }
      });

      test('classifies permanent client errors correctly', () {
        final clientErrors = [
          'Client error 403: Forbidden',
          'Client error 404: Not Found',
          'Client error 400: Bad Request',
        ];

        for (final error in clientErrors) {
          final result = UploadErrorClassifier.classifyError(Exception(error));
          expect(result, equals(UploadErrorType.permanentClient),
              reason: 'Should classify "$error" as permanent client error');
        }
      });

      test('excludes 429 from permanent client errors', () {
        final result = UploadErrorClassifier.classifyError(
            Exception('Client error 429: Too Many Requests'));
        expect(result, equals(UploadErrorType.temporary),
            reason:
                'Should classify 429 as temporary error, not permanent client error');
      });

      test('defaults to temporary for unknown errors', () {
        final unknownErrors = [
          'Unknown error',
          'Network error',
          'Some other error',
        ];

        for (final error in unknownErrors) {
          final result = UploadErrorClassifier.classifyError(Exception(error));
          expect(result, equals(UploadErrorType.temporary),
              reason: 'Should classify "$error" as temporary error by default');
        }
      });

      test('prioritizes permanent auth over other classifications', () {
        // This error contains both "Server error" (temporary) and "Authentication failed" (permanent auth)
        final mixedError =
            'Server error 500: Authentication failed - user needs to re-login';
        final result =
            UploadErrorClassifier.classifyError(Exception(mixedError));
        expect(result, equals(UploadErrorType.permanentAuth),
            reason:
                'Should prioritize permanent auth over temporary classification');
      });
    });
  });

  group('DirectUploadService Tests', () {
    late DirectUploadService directUploadService;
    late MockOpenSenseMapService mockOpenSenseMapService;
    late MockSettingsBloc mockSettingsBloc;
    late MockOpenSenseMapBloc mockOpenSenseMapBloc;
    late MockTrackService mockTrackService;
    late SenseBox mockSenseBox;

    setUp(() {
      mockOpenSenseMapService = MockOpenSenseMapService();
      mockSettingsBloc = MockSettingsBloc();
      mockOpenSenseMapBloc = MockOpenSenseMapBloc();
      
      when(() => mockOpenSenseMapBloc.markAuthenticationFailed()).thenAnswer((_) async {});

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

      // Setup default mock behavior
      when(() => mockOpenSenseMapBloc.markAuthenticationFailed())
          .thenAnswer((_) async {});
      when(() => mockTrackService.markTrackAsUploaded(any()))
          .thenAnswer((_) async => Future.value(true)); // Mock success for now

      directUploadService = DirectUploadService(
        openSenseMapService: mockOpenSenseMapService,
        settingsBloc: mockSettingsBloc,
        senseBox: mockSenseBox,
        openSenseMapBloc: mockOpenSenseMapBloc,
        trackService: mockTrackService,
        trackId: 1,
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

        directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
        await directUploadService.uploadRemainingBufferedData();

        // Verify that markTrackAsUploaded was NOT called
        verifyNever(() => mockTrackService.markTrackAsUploaded(any()));

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

        directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);

        // Trigger upload which should not mark track as uploaded
        await directUploadService.uploadRemainingBufferedData();

        // Verify that markTrackAsUploaded was NOT called
        verifyNever(() => mockTrackService.markTrackAsUploaded(any()));

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

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

      directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

        directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

        directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

        directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
        await directUploadService.uploadRemainingBufferedData();

        // Service should remain enabled since bloc handles authentication
        expect(directUploadService.isEnabled, true);
        // No restart timer should be scheduled for auth errors
        expect(directUploadService.hasPendingRestartTimer, false);
        // Data should be cleared after upload attempt (even on auth errors)
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

        directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

        directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
        await directUploadService.uploadRemainingBufferedData();

        // Service should remain enabled since bloc handles authentication
        expect(directUploadService.isEnabled, true);
        // No restart timer should be scheduled for auth errors
        expect(directUploadService.hasPendingRestartTimer, false);
        // Data should be cleared after upload attempt (even on auth errors)
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

        directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

        directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
        await directUploadService.uploadRemainingBufferedData();

        // Service should be disabled for 404 client errors (permanent)
        expect(directUploadService.isEnabled, false);
        // Restart timer should be scheduled for client errors
        expect(directUploadService.hasPendingRestartTimer, true);
        // Data should be cleared during final upload attempt
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

          directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
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

          directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
          await directUploadService.uploadRemainingBufferedData();

          expect(directUploadService.isEnabled, true,
              reason: 'Service should remain enabled for auth error: $error');
          expect(directUploadService.hasPendingRestartTimer, false,
              reason: 'No restart should be scheduled for auth error: $error');
          // Data should be cleared during final upload attempt
          expect(directUploadService.hasPreservedData, false,
              reason:
                  'Data should be cleared after upload attempt for auth error: $error');

          directUploadService.dispose();
        }
      });
    });



  });
} 