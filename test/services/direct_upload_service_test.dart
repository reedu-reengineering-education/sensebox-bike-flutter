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
import 'package:sensebox_bike/feature_flags.dart';

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}
class MockSettingsBloc extends Mock implements SettingsBloc {}
class MockOpenSenseMapBloc extends Mock implements OpenSenseMapBloc {}

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
    late SenseBox mockSenseBox;

    setUp(() {
      mockOpenSenseMapService = MockOpenSenseMapService();
      mockSettingsBloc = MockSettingsBloc();
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

      // Setup default mock behavior
      when(() => mockOpenSenseMapBloc.markAuthenticationFailed())
          .thenAnswer((_) async {});

      directUploadService = DirectUploadService(
        openSenseMapService: mockOpenSenseMapService,
        settingsBloc: mockSettingsBloc,
        senseBox: mockSenseBox,
        openSenseMapBloc: mockOpenSenseMapBloc,
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

      // Setup mock to be authenticated
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

      // Setup mock to throw temporary authentication error
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
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
        'disables service for permanent authentication failures - no refresh token',
        () async {
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);

      // Setup mock to be authenticated initially
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

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

      // Setup mock to be authenticated initially
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

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

      // Setup mock to be authenticated initially
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

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

      // Setup mock to be authenticated initially
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

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

      // Setup mock to be authenticated
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

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

      // Setup mock to be authenticated
      when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

      // Setup mock to throw rate limiting error
      when(() => mockOpenSenseMapService.uploadData(any(), any()))
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

    // New comprehensive error handling tests
    group('Error Handling Tests', () {
      test('handles 429 rate limiting error correctly', () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw 429 rate limiting error
        when(() => mockOpenSenseMapService.uploadData(any(), any()))
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
        when(() => mockOpenSenseMapService.uploadData(any(), any()))
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
          'handles permanent authentication error correctly - no restart scheduled',
          () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated initially
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw permanent authentication error
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

        // Service should be permanently disabled for authentication failures
        expect(directUploadService.isEnabled, false);
        // No restart timer should be scheduled for auth errors
        expect(directUploadService.hasPendingRestartTimer, false);
        // Data should be cleared
        expect(directUploadService.hasPreservedData, false);
      });

      test('handles token refresh error correctly', () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw token refresh error
        when(() => mockOpenSenseMapService.uploadData(any(), any()))
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

      test('handles "Not authenticated" error correctly - permanent auth error',
          () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated initially
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw "Not authenticated" error
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

        // Service should be permanently disabled for "Not authenticated" errors (treated as permanent auth error)
        expect(directUploadService.isEnabled, false);
        // No restart timer should be scheduled for auth errors
        expect(directUploadService.hasPendingRestartTimer, false);
        // Data should be cleared
        expect(directUploadService.hasPreservedData, false);
      });

      test('handles timeout error correctly', () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw timeout error
        when(() => mockOpenSenseMapService.uploadData(any(), any())).thenThrow(
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
        expect(directUploadService.hasPreservedData, false);
      });

      test('handles 404 client error correctly', () async {
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);

        // Setup mock to be authenticated initially
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

        // Setup mock to throw 404 client error
        when(() => mockOpenSenseMapService.uploadData(any(), any()))
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
        // Data should be cleared
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

          when(() => mockOpenSenseMapService.uploadData(any(), any()))
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
          expect(directUploadService.hasPreservedData, false,
              reason:
                  'Data should be cleared during final upload for error: $error');

          directUploadService.dispose();
        }

        // Test that permanent authentication errors disable service without restart
        final permanentAuthErrors = [
          'Authentication failed - user needs to re-login',
          'No refresh token found',
          'Failed to refresh token: Network error',
          'Not authenticated',
        ];

        for (final error in permanentAuthErrors) {
          directUploadService.enable();
          expect(directUploadService.isEnabled, true);

          // Setup mock to be authenticated initially
          when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);

          when(() => mockOpenSenseMapService.uploadData(any(), any()))
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

          expect(directUploadService.isEnabled, false,
              reason: 'Service should be disabled for auth error: $error');
          expect(directUploadService.hasPendingRestartTimer, false,
              reason: 'No restart should be scheduled for auth error: $error');
          expect(directUploadService.hasPreservedData, false,
              reason: 'Data should be cleared for auth error: $error');

          directUploadService.dispose();
        }
      });
    });

    test('disables live uploads when feature flag is false', () async {
      // Test that data is preserved locally when feature flag disables live uploads
      FeatureFlags.enableLiveUpload = false;
      
      directUploadService.enable();
      expect(directUploadService.isEnabled, true);
      expect(directUploadService.isUploadDisabled, true);

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

      // Add data - should be stored locally even when live uploads are disabled
      final result = directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
      
      expect(result, true);
      expect(directUploadService.hasPreservedData, true);

      // Verify that no live upload was attempted
      verifyNever(() => mockOpenSenseMapService.uploadData(any(), any()));
    });

    // Feature Flag Tests
    group('Feature Flag Tests', () {
      setUp(() {
        // Reset feature flag to default state before each test
        FeatureFlags.enableLiveUpload = false;
      });

      test('enables live uploads when feature flag is true', () async {
        // Enable feature flag
        FeatureFlags.enableLiveUpload = true;
        
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);
        expect(directUploadService.isLiveUploadDisabledByFeatureFlag, false);
        expect(directUploadService.isUploadDisabled, false);

        // Setup mock to be authenticated and accepting requests
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);
        when(() => mockOpenSenseMapService.isAcceptingRequests).thenReturn(true);
        when(() => mockOpenSenseMapService.uploadData(any(), any()))
            .thenAnswer((_) async {});

        // Create GPS points for the buffer
        final gpsPoints = <GeolocationData>[];
        final groupedData = <GeolocationData, Map<String, List<double>>>{};
        
        for (int i = 0; i < 6; i++) {
          final gpsPoint = GeolocationData()
            ..latitude = 10.0 + i
            ..longitude = 20.0 + i
            ..speed = 5.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, i, 0);
          
          gpsPoints.add(gpsPoint);
          groupedData[gpsPoint] = {
            'temperature': [22.5 + i],
          };
        }
        
        // Add all data at once to trigger upload threshold (6 GPS points)
        directUploadService.addGroupedDataForUpload(groupedData, gpsPoints);

        // Wait a bit for async operations
        await Future.delayed(Duration(milliseconds: 100));

        // Verify that upload was attempted when feature flag is enabled
        verify(() => mockOpenSenseMapService.uploadData(any(), any())).called(greaterThan(0));
      });

      test('preserves data preparation logic when feature flag is false', () async {
        // Ensure feature flag is false
        FeatureFlags.enableLiveUpload = false;
        
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);
        expect(directUploadService.isUploadDisabled, true);

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

        // Add data - should be accepted for local storage
        final result = directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
        expect(result, true);
        expect(directUploadService.hasPreservedData, true);

        // Data should be available for batch upload later via uploadRemainingBufferedData
        // This tests that data preparation logic is preserved
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);
        when(() => mockOpenSenseMapService.uploadData(any(), any()))
            .thenAnswer((_) async {});

        await directUploadService.uploadRemainingBufferedData();
        
        // Verify that the data was uploaded via the batch method
        verify(() => mockOpenSenseMapService.uploadData(any(), any())).called(1);
      });

      test('feature flag change requires service restart to take effect', () async {
        // Start with feature flag disabled
        FeatureFlags.enableLiveUpload = false;
        directUploadService.enable();
        expect(directUploadService.isUploadDisabled, true);

        // Change feature flag but don't restart service
        FeatureFlags.enableLiveUpload = true;
        // Service should still have uploads disabled until restarted
        expect(directUploadService.isUploadDisabled, true);

        // Restart service
        directUploadService.enable();
        // Now uploads should be enabled
        expect(directUploadService.isUploadDisabled, false);
      });

      tearDown(() {
        // Reset feature flag to default after each test
        FeatureFlags.enableLiveUpload = false;
      });

      test('preserves data preparation logic when feature flag is false', () async {
        // Ensure feature flag is false
        FeatureFlags.enableLiveUpload = false;
        
        directUploadService.enable();
        expect(directUploadService.isEnabled, true);
        expect(directUploadService.isUploadDisabled, true);

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

        // Add data - should be accepted for local storage
        final result = directUploadService.addGroupedDataForUpload(groupedData, gpsBuffer);
        expect(result, true);
        expect(directUploadService.hasPreservedData, true);

        // Data should be available for batch upload later via uploadRemainingBufferedData
        // This tests that data preparation logic is preserved
        when(() => mockOpenSenseMapBloc.isAuthenticated).thenReturn(true);
        when(() => mockOpenSenseMapService.uploadData(any(), any()))
            .thenAnswer((_) async {});

        await directUploadService.uploadRemainingBufferedData();
        
        // Verify that the data was uploaded via the batch method
        verify(() => mockOpenSenseMapService.uploadData(any(), any())).called(1);
      });

      test('feature flag change requires service restart to take effect', () async {
        // Start with feature flag disabled
        FeatureFlags.enableLiveUpload = false;
        directUploadService.enable();
        expect(directUploadService.isUploadDisabled, true);

        // Change feature flag but don't restart service
        FeatureFlags.enableLiveUpload = true;
        // Service should still have uploads disabled until restarted
        expect(directUploadService.isUploadDisabled, true);

        // Restart service
        directUploadService.enable();
        // Now uploads should be enabled
        expect(directUploadService.isUploadDisabled, false);
      });

      tearDown(() {
        // Reset feature flag to default after each test
        FeatureFlags.enableLiveUpload = false;
      });
    });
  });
} 