import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/services/upload_error_classifier.dart';
import 'package:sensebox_bike/services/error_service.dart';

/// Manages retry logic for upload operations with exponential backoff
class UploadRetryManager {
  static const int _defaultMaxAttempts = 3;
  static const Duration _defaultInitialDelay = Duration(seconds: 1);
  static const double _defaultBackoffMultiplier = 2.0;
  static const Duration _defaultMaxDelay = Duration(minutes: 5);

  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const UploadRetryManager({
    this.maxAttempts = _defaultMaxAttempts,
    this.initialDelay = _defaultInitialDelay,
    this.backoffMultiplier = _defaultBackoffMultiplier,
    this.maxDelay = _defaultMaxDelay,
  });

  /// Executes a function with retry logic based on error classification.
  /// 
  /// Implements exponential backoff for temporary errors and preserves data
  /// locally when operations fail. Provides comprehensive logging for monitoring.
  /// 
  /// [operation] - The async function to execute
  /// [onRetry] - Optional callback called before each retry attempt
  /// 
  /// Returns the result of the operation if successful
  /// Throws the last error if all retry attempts fail
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    void Function(Exception exception, int attempt)? onRetry,
  }) async {
    int attemptCount = 0;
    Exception? lastException;
    final startTime = DateTime.now();
    
    _logInfo('Retry session start', 'Starting retry session with max $maxAttempts attempts');
    
    while (attemptCount < maxAttempts) {
      attemptCount++;
      
      try {
        _logInfo('Operation attempt', 'Executing operation attempt $attemptCount/$maxAttempts');
        final result = await operation();
        
        if (attemptCount > 1) {
          final duration = DateTime.now().difference(startTime);
          _logInfo('Retry success', 'Operation succeeded on attempt $attemptCount after ${duration.inMilliseconds}ms');
        }
        
        return result;
      } catch (e, stackTrace) {
        lastException = e as Exception;
        
        _logError('Operation failed', 'Attempt $attemptCount failed: $e');
        
        // Check if we should retry this error
        if (!_shouldRetry(lastException)) {
          _logError('Non-retryable error', 'Error classified as non-retryable, stopping attempts');
          
          // Report permanent errors to error service
          ErrorService.handleError(
            'Non-retryable error in retry manager: $e',
            stackTrace,
            sendToSentry: true,
          );
          
          throw lastException;
        }
        
        // If this is not the last attempt, call onRetry and wait
        if (attemptCount < maxAttempts) {
          final nextAttempt = attemptCount + 1;
          final delay = _calculateDelay(attemptCount);
          
          _logInfo('Retry scheduled', 'Scheduling retry attempt $nextAttempt in ${delay.inMilliseconds}ms');
          
          if (onRetry != null) {
            onRetry(lastException, nextAttempt);
          }
          
          // Apply exponential backoff delay
          await Future.delayed(delay);
        } else {
          _logError('Max attempts reached', 'All $maxAttempts attempts failed');
          
          // Report final failure to error service
          ErrorService.handleError(
            'All retry attempts failed: $e',
            stackTrace,
            sendToSentry: true,
          );
        }
      }
    }
    
    // If we get here, all attempts failed
    final totalDuration = DateTime.now().difference(startTime);
    _logError('Retry session failed', 'Retry session failed after ${totalDuration.inMilliseconds}ms and $maxAttempts attempts');
    
    throw lastException!;
  }

  /// Determines if an error should be retried based on error classification
  bool _shouldRetry(Exception exception) {
    final errorType = UploadErrorClassifier.classifyError(exception);
    
    switch (errorType) {
      case UploadErrorType.temporary:
        return true;
      case UploadErrorType.permanentAuth:
      case UploadErrorType.permanentClient:
        return false;
    }
  }

  /// Calculates delay for retry attempts using exponential backoff
  Duration _calculateDelay(int attempt) {
    final delay = Duration(
      milliseconds: (initialDelay.inMilliseconds * 
                    pow(backoffMultiplier, attempt - 1)).round(),
    );
    
    // Cap the delay at maxDelay
    return delay > maxDelay ? maxDelay : delay;
  }

  /// Creates a retry manager optimized for network operations
  factory UploadRetryManager.forNetworkOperations() {
    return const UploadRetryManager(
      maxAttempts: 3,
      initialDelay: Duration(seconds: 2),
      backoffMultiplier: 2.0,
      maxDelay: Duration(minutes: 2),
    );
  }

  /// Creates a retry manager optimized for rate-limited operations
  factory UploadRetryManager.forRateLimitedOperations() {
    return const UploadRetryManager(
      maxAttempts: 5,
      initialDelay: Duration(seconds: 5),
      backoffMultiplier: 1.5,
      maxDelay: Duration(minutes: 10),
    );
  }

  /// Creates a retry manager for testing with shorter delays
  factory UploadRetryManager.forTesting() {
    return const UploadRetryManager(
      maxAttempts: 2,
      initialDelay: Duration(milliseconds: 100),
      backoffMultiplier: 2.0,
      maxDelay: Duration(seconds: 1),
    );
  }

  /// Logs informational messages with structured format
  void _logInfo(String operation, String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [UploadRetryManager] [INFO] [$operation] $message');
  }

  /// Logs error messages with structured format
  void _logError(String operation, String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [UploadRetryManager] [ERROR] [$operation] $message');
  }
}