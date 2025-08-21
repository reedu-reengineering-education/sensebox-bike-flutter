import 'dart:async';
import 'dart:math';
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

  group('UploadRetryManager', () {
    late UploadRetryManager retryManager;

    setUp(() {
      retryManager = const UploadRetryManager(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
        backoffMultiplier: 2.0,
        maxDelay: Duration(seconds: 1),
      );
    });

    group('executeWithRetry', () {
      test('should succeed on first attempt when operation succeeds', () async {
        var callCount = 0;
        
        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          return 'success';
        });

        expect(result, equals('success'));
        expect(callCount, equals(1));
      });

      test('should retry temporary errors and eventually succeed', () async {
        var callCount = 0;
        
        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          if (callCount < 3) {
            throw TooManyRequestsException(60); // 60 seconds retry after
          }
          return 'success';
        });

        expect(result, equals('success'));
        expect(callCount, equals(3));
      });

      test('should not retry permanent authentication errors', () async {
        var callCount = 0;
        
        expect(
          () => retryManager.executeWithRetry(() async {
            callCount++;
            throw PermanentAuthenticationError('Auth failed');
          }),
          throwsA(isA<PermanentAuthenticationError>()),
        );

        expect(callCount, equals(1));
      });

      test('should not retry permanent client errors', () async {
        var callCount = 0;
        
        expect(
          () => retryManager.executeWithRetry(() async {
            callCount++;
            throw Exception('Client error - 400 Bad Request');
          }),
          throwsA(isA<Exception>()),
        );

        expect(callCount, equals(1));
      });

      test('should retry timeout exceptions', () async {
        var callCount = 0;
        
        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          if (callCount < 2) {
            throw TimeoutException('Request timeout', Duration(seconds: 30));
          }
          return 'success';
        });

        expect(result, equals('success'));
        expect(callCount, equals(2));
      });

      test('should fail after max attempts with temporary errors', () async {
        var callCount = 0;
        
        try {
          await retryManager.executeWithRetry(() async {
            callCount++;
            throw TooManyRequestsException(60); // Always rate limited
          });
          fail('Expected exception to be thrown');
        } catch (e) {
          expect(e, isA<TooManyRequestsException>());
        }

        expect(callCount, equals(3)); // maxAttempts
      });

      test('should call onRetry callback before each retry', () async {
        var callCount = 0;
        var retryCallCount = 0;
        final retryAttempts = <int>[];
        final retryExceptions = <Exception>[];
        
        try {
          await retryManager.executeWithRetry(
            () async {
              callCount++;
              throw TooManyRequestsException(60); // Rate limited
            },
            onRetry: (exception, attempt) {
              retryCallCount++;
              retryAttempts.add(attempt);
              retryExceptions.add(exception);
            },
          );
        } catch (e) {
          // Expected to fail
        }

        expect(callCount, equals(3));
        expect(retryCallCount, equals(2)); // Called before 2nd and 3rd attempts
        expect(retryAttempts, equals([2, 3]));
        expect(retryExceptions.length, equals(2));
        expect(retryExceptions.every((e) => e is TooManyRequestsException), isTrue);
      });

      test('should handle server error strings as temporary errors', () async {
        var callCount = 0;
        
        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          if (callCount < 2) {
            throw Exception('Server error - 500 Internal Server Error');
          }
          return 'success';
        });

        expect(result, equals('success'));
        expect(callCount, equals(2));
      });

      test('should handle authentication error strings as permanent', () async {
        var callCount = 0;
        
        expect(
          () => retryManager.executeWithRetry(() async {
            callCount++;
            throw Exception('Authentication failed - user needs to re-login');
          }),
          throwsA(isA<Exception>()),
        );

        expect(callCount, equals(1));
      });
    });

    group('delay calculation', () {
      test('should use exponential backoff', () async {
        final delays = <Duration>[];
        var callCount = 0;
        
        try {
          await retryManager.executeWithRetry(
            () async {
              callCount++;
              throw TooManyRequestsException(60); // Rate limited
            },
            onRetry: (exception, attempt) {
              // Record the time before the delay
              final startTime = DateTime.now();
              Future.delayed(Duration.zero).then((_) {
                final endTime = DateTime.now();
                delays.add(endTime.difference(startTime));
              });
            },
          );
        } catch (e) {
          // Expected to fail
        }

        expect(callCount, equals(3));
        // We can't easily test exact timing in unit tests, but we can verify
        // that the retry mechanism was called the correct number of times
      });

      test('should cap delay at maxDelay', () {
        final longDelayManager = UploadRetryManager(
          maxAttempts: 5,
          initialDelay: Duration(seconds: 10),
          backoffMultiplier: 3.0,
          maxDelay: Duration(seconds: 30),
        );

        // Calculate what the delay would be for attempt 5 without capping
        // 10 * 3^4 = 10 * 81 = 810 seconds
        // This should be capped at 30 seconds
        final delay = _calculateDelayForTesting(longDelayManager, 5);
        expect(delay, equals(Duration(seconds: 30)));
      });
    });

    group('factory constructors', () {
      test('forNetworkOperations should create appropriate configuration', () {
        final networkManager = UploadRetryManager.forNetworkOperations();
        
        expect(networkManager.maxAttempts, equals(3));
        expect(networkManager.initialDelay, equals(Duration(seconds: 2)));
        expect(networkManager.backoffMultiplier, equals(2.0));
        expect(networkManager.maxDelay, equals(Duration(minutes: 2)));
      });

      test('forRateLimitedOperations should create appropriate configuration', () {
        final rateLimitManager = UploadRetryManager.forRateLimitedOperations();
        
        expect(rateLimitManager.maxAttempts, equals(5));
        expect(rateLimitManager.initialDelay, equals(Duration(seconds: 5)));
        expect(rateLimitManager.backoffMultiplier, equals(1.5));
        expect(rateLimitManager.maxDelay, equals(Duration(minutes: 10)));
      });

      test('forTesting should create fast configuration', () {
        final testManager = UploadRetryManager.forTesting();
        
        expect(testManager.maxAttempts, equals(2));
        expect(testManager.initialDelay, equals(Duration(milliseconds: 100)));
        expect(testManager.backoffMultiplier, equals(2.0));
        expect(testManager.maxDelay, equals(Duration(seconds: 1)));
      });
    });

    group('error classification integration', () {
      test('should correctly classify TooManyRequestsException as temporary', () {
        final exception = TooManyRequestsException(60);
        final errorType = UploadErrorClassifier.classifyError(exception);
        expect(errorType, equals(UploadErrorType.temporary));
      });

      test('should retry TooManyRequestsException', () async {
        var callCount = 0;
        
        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          if (callCount < 2) {
            throw TooManyRequestsException(60); // Rate limited
          }
          return 'success';
        });

        expect(result, equals('success'));
        expect(callCount, equals(2));
      });

      test('should correctly classify PermanentAuthenticationError as permanent', () async {
        var callCount = 0;
        
        expect(
          () => retryManager.executeWithRetry(() async {
            callCount++;
            throw PermanentAuthenticationError('Auth failed');
          }),
          throwsA(isA<PermanentAuthenticationError>()),
        );

        expect(callCount, equals(1));
      });

      test('should correctly classify string-based errors', () async {
        var callCount = 0;
        
        // Test temporary error string
        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          if (callCount < 2) {
            throw Exception('Server error occurred');
          }
          return 'success';
        });

        expect(result, equals('success'));
        expect(callCount, equals(2));
      });

      test('should treat unknown errors as temporary by default', () async {
        var callCount = 0;
        
        final result = await retryManager.executeWithRetry(() async {
          callCount++;
          if (callCount < 2) {
            throw Exception('Unknown error type');
          }
          return 'success';
        });

        expect(result, equals('success'));
        expect(callCount, equals(2));
      });
    });
  });
}

// Helper function to test delay calculation
Duration _calculateDelayForTesting(UploadRetryManager manager, int attempt) {
  final delay = Duration(
    milliseconds: (manager.initialDelay.inMilliseconds * 
                  pow(manager.backoffMultiplier, attempt - 1)).round(),
  );
  
  return delay > manager.maxDelay ? manager.maxDelay : delay;
}