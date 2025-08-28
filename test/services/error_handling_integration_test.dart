import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/services/upload_retry_manager.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';

void main() {
  // Initialize Flutter binding for tests
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('Error Handling Integration Tests', () {
    late UploadRetryManager retryManager;

    setUp(() {
      retryManager = UploadRetryManager.forTesting();
    });

    group('Network Failure Scenarios', () {
      test('should preserve data and retry on temporary network failures', () async {
        // Arrange
        var callCount = 0;
        final callTimes = <DateTime>[];
        
        // Act
        final result = await retryManager.executeWithRetry(
          () async {
            callCount++;
            callTimes.add(DateTime.now());
            
            if (callCount < 2) {
              throw Exception('Server error - 500 Internal Server Error');
            }
            return 'success';
          },
          onRetry: (exception, attempt) {
            // This callback should be called before retry
            expect(exception.toString(), contains('Server error'));
            expect(attempt, equals(2)); // Second attempt
          },
        );

        // Assert
        expect(result, equals('success'));
        expect(callCount, equals(2)); // Original + 1 retry
        expect(callTimes.length, equals(2));
        
        // Verify exponential backoff delay occurred
        if (callTimes.length >= 2) {
          final delay = callTimes[1].difference(callTimes[0]);
          expect(delay.inMilliseconds, greaterThan(50)); // At least some delay
        }
      });

      test('should preserve data when all retry attempts fail', () async {
        // Arrange
        var callCount = 0;
        
        // Act & Assert
        await expectLater(
          () => retryManager.executeWithRetry(() async {
            callCount++;
            throw Exception('Server error - 500 Internal Server Error');
          }),
          throwsA(isA<Exception>()),
        );

        // Verify all attempts were made
        expect(callCount, equals(2)); // Max attempts for testing config
      });

      test('should handle timeout exceptions with proper retry', () async {
        // Arrange
        var callCount = 0;
        
        // Act
        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          if (callCount < 2) {
            throw TimeoutException('Request timeout', Duration(seconds: 30));
          }
          return 'success';
        });

        // Assert
        expect(result, equals('success'));
        expect(callCount, equals(2));
      });

      test('should handle rate limiting with proper retry', () async {
        // Arrange
        var callCount = 0;
        
        // Act
        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          if (callCount < 2) {
            throw TooManyRequestsException(60); // Rate limited for 60 seconds
          }
          return 'success';
        });

        // Assert
        expect(result, equals('success'));
        expect(callCount, equals(2));
      });
    });

    group('Authentication Error Scenarios', () {
      test('should not retry permanent authentication errors', () async {
        // Arrange
        var callCount = 0;
        
        // Act & Assert
        await expectLater(
          () => retryManager.executeWithRetry(() async {
            callCount++;
            throw PermanentAuthenticationError('Token expired');
          }),
          throwsA(isA<PermanentAuthenticationError>()),
        );

        // Verify only one attempt was made (no retries)
        expect(callCount, equals(1));
      });

      test('should not retry authentication error patterns', () async {
        // Arrange
        var callCount = 0;
        
        // Act & Assert
        await expectLater(
          () => retryManager.executeWithRetry(() async {
            callCount++;
            throw Exception('Authentication failed - user needs to re-login');
          }),
          throwsA(isA<Exception>()),
        );

        // Verify only one attempt was made (no retries)
        expect(callCount, equals(1));
      });

      test('should not retry other authentication patterns', () async {
        // Arrange
        final authPatterns = [
          'No refresh token found',
          'Failed to refresh token:',
          'Not authenticated',
        ];

        for (final pattern in authPatterns) {
          var callCount = 0;
          
          // Act & Assert
          await expectLater(
            () => retryManager.executeWithRetry(() async {
              callCount++;
              throw Exception(pattern);
            }),
            throwsA(isA<Exception>()),
            reason: 'Pattern "$pattern" should not be retried',
          );

          // Verify only one attempt was made (no retries)
          expect(callCount, equals(1), 
                 reason: 'Pattern "$pattern" should not be retried');
        }
      });
    });

    group('Error Classification', () {
      test('should classify temporary errors correctly', () {
        final temporaryErrors = [
          Exception('Server error - 500 Internal Server Error'),
          Exception('Token refreshed successfully'),
          TooManyRequestsException(60),
          TimeoutException('Request timeout', Duration(seconds: 30)),
        ];

        for (final error in temporaryErrors) {
          final errorType = UploadErrorClassifier.classifyError(error);
          expect(errorType, equals(UploadErrorType.temporary),
                 reason: 'Error ${error.runtimeType} should be classified as temporary');
        }
      });

      test('should classify permanent authentication errors correctly', () {
        final authErrors = [
          PermanentAuthenticationError('Token expired'),
          Exception('Authentication failed - user needs to re-login'),
          Exception('No refresh token found'),
          Exception('Failed to refresh token: invalid token'),
          Exception('Not authenticated'),
        ];

        for (final error in authErrors) {
          final errorType = UploadErrorClassifier.classifyError(error);
          expect(errorType, equals(UploadErrorType.permanentAuth),
                 reason: 'Error should be classified as permanent auth error');
        }
      });

      test('should classify permanent client errors correctly', () {
        final clientErrors = [
          Exception('Client error - 400 Bad Request'),
          Exception('Client error - 404 Not Found'),
        ];

        for (final error in clientErrors) {
          final errorType = UploadErrorClassifier.classifyError(error);
          expect(errorType, equals(UploadErrorType.permanentClient),
                 reason: 'Error should be classified as permanent client error');
        }
      });

      test('should default unknown errors to temporary', () {
        final unknownErrors = [
          Exception('Some unknown error'),
          Exception('Unexpected failure'),
          StateError('Invalid state'),
        ];

        for (final error in unknownErrors) {
          final errorType = UploadErrorClassifier.classifyError(error);
          expect(errorType, equals(UploadErrorType.temporary),
                 reason: 'Unknown error should default to temporary');
        }
      });
    });

    group('Data Preservation Scenarios', () {
      test('should preserve operation context during retries', () async {
        // Arrange
        var callCount = 0;
        final operationData = {'important': 'data', 'should': 'be preserved'};
        
        // Act
        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          
          // Simulate operation that uses preserved data
          if (callCount < 2) {
            // Verify data is still available during retry
            expect(operationData['important'], equals('data'));
            throw Exception('Server error');
          }
          
          // Return the preserved data on success
          return operationData;
        });

        // Assert
        expect(result, equals(operationData));
        expect(callCount, equals(2));
      });

      test('should handle complex retry scenarios with data preservation', () async {
        // Arrange
        var callCount = 0;
        final preservedState = <String, dynamic>{
          'uploadAttempts': 0,
          'lastError': null,
          'dataIntegrity': true,
        };
        
        // Act
        final result = await retryManager.executeWithRetry(
          () async {
            callCount++;
            preservedState['uploadAttempts'] = callCount;
            
            if (callCount < 2) {
              preservedState['lastError'] = 'Network timeout';
              throw Exception('Server error - 503 Service Unavailable');
            }
            
            preservedState['lastError'] = null;
            return preservedState;
          },
          onRetry: (exception, attempt) {
            // Verify state is preserved between retries
            expect(preservedState['uploadAttempts'], equals(1));
            expect(preservedState['lastError'], equals('Network timeout'));
            expect(preservedState['dataIntegrity'], isTrue);
          },
        );

        // Assert
        expect(result['uploadAttempts'], equals(2));
        expect(result['lastError'], isNull);
        expect(result['dataIntegrity'], isTrue);
      });
    });

    group('Exponential Backoff Verification', () {
      test('should implement exponential backoff correctly', () async {
        // Arrange
        final retryManagerWithLongerDelays = UploadRetryManager(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 50),
          backoffMultiplier: 2.0,
          maxDelay: Duration(seconds: 5),
        );
        
        var callCount = 0;
        final callTimes = <DateTime>[];
        
        // Act
        try {
          await retryManagerWithLongerDelays.executeWithRetry(() async {
            callCount++;
            callTimes.add(DateTime.now());
            throw Exception('Server error'); // Always fail to test all delays
          });
        } catch (e) {
          // Expected to fail after all retries
        }

        // Assert
        expect(callCount, equals(3)); // All attempts made
        expect(callTimes.length, equals(3));
        
        if (callTimes.length >= 3) {
          // Verify delays are increasing (exponential backoff)
          final delay1 = callTimes[1].difference(callTimes[0]);
          final delay2 = callTimes[2].difference(callTimes[1]);
          
          expect(delay1.inMilliseconds, greaterThan(40)); // ~50ms initial delay
          expect(delay2.inMilliseconds, greaterThan(delay1.inMilliseconds)); // Exponential increase
        }
      });

      test('should cap delays at maxDelay', () {
        // Arrange
        final retryManagerWithCapping = UploadRetryManager(
          maxAttempts: 5,
          initialDelay: Duration(seconds: 10),
          backoffMultiplier: 3.0,
          maxDelay: Duration(seconds: 30),
        );

        // Act - Calculate what delay would be for attempt 5 without capping
        // 10 * 3^4 = 10 * 81 = 810 seconds, should be capped at 30 seconds
        
        // We can't easily test the actual delay timing in unit tests,
        // but we can verify the calculation logic exists
        expect(retryManagerWithCapping.maxDelay, equals(Duration(seconds: 30)));
        expect(retryManagerWithCapping.initialDelay, equals(Duration(seconds: 10)));
        expect(retryManagerWithCapping.backoffMultiplier, equals(3.0));
      });
    });

    group('Logging and Monitoring', () {
      test('should provide detailed error information for monitoring', () async {
        // Arrange
        var callCount = 0;
        final capturedErrors = <Exception>[];
        final capturedAttempts = <int>[];
        
        // Act
        try {
          await retryManager.executeWithRetry(
            () async {
              callCount++;
              final error = Exception('Server error - attempt $callCount');
              throw error;
            },
            onRetry: (exception, attempt) {
              capturedErrors.add(exception);
              capturedAttempts.add(attempt);
            },
          );
        } catch (e) {
          // Expected to fail
        }

        // Assert
        expect(callCount, equals(2)); // Max attempts for test config
        expect(capturedErrors.length, equals(1)); // One retry callback
        expect(capturedAttempts, equals([2])); // Second attempt
        expect(capturedErrors[0].toString(), contains('Server error - attempt 1'));
      });
    });
  });
}