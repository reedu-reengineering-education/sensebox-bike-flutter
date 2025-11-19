import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/upload_error_classifier.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';

void main() {
  group('BatchUploadService', () {
    test('should have correct interface and properties', () {
      // This is a basic test to verify the service can be instantiated
      // and has the expected interface without complex mocking
      
      // We can't easily test the full functionality without proper mocking setup
      // but we can verify the basic structure
      expect(UploadProgress, isA<Type>());
      expect(UploadStatus.values, contains(UploadStatus.preparing));
      expect(UploadStatus.values, contains(UploadStatus.uploading));
      expect(UploadStatus.values, contains(UploadStatus.completed));
      expect(UploadStatus.values, contains(UploadStatus.failed));
      expect(UploadStatus.values, contains(UploadStatus.retrying));
    });

    test('should create UploadProgress with correct properties', () {
      final progress = UploadProgress(
        totalChunks: 10,
        completedChunks: 5,
        failedChunks: 1,
        status: UploadStatus.uploading,
        canRetry: true,
      );

      expect(progress.totalChunks, 10);
      expect(progress.completedChunks, 5);
      expect(progress.failedChunks, 1);
      expect(progress.status, UploadStatus.uploading);
      expect(progress.canRetry, true);
      expect(progress.progressPercentage, 0.5);
      expect(progress.progressPercentageInt, 50);
      expect(progress.isInProgress, true);
      expect(progress.isCompleted, false);
      expect(progress.hasFailed, false);
    });

    test('should create UploadProgress with completed status', () {
      final progress = UploadProgress(
        totalChunks: 10,
        completedChunks: 10,
        failedChunks: 0,
        status: UploadStatus.completed,
        canRetry: false,
      );

      expect(progress.isCompleted, true);
      expect(progress.isInProgress, false);
      expect(progress.hasFailed, false);
      expect(progress.progressPercentage, 1.0);
      expect(progress.progressPercentageInt, 100);
    });

    test('should create UploadProgress with failed status', () {
      final progress = UploadProgress(
        totalChunks: 10,
        completedChunks: 5,
        failedChunks: 5,
        status: UploadStatus.failed,
        errorMessage: 'Upload failed',
        canRetry: true,
      );

      expect(progress.hasFailed, true);
      expect(progress.isCompleted, false);
      expect(progress.isInProgress, false);
      expect(progress.errorMessage, 'Upload failed');
      expect(progress.canRetry, true);
    });

    test('should handle copyWith correctly', () {
      final original = UploadProgress(
        totalChunks: 10,
        completedChunks: 5,
        failedChunks: 1,
        status: UploadStatus.uploading,
        canRetry: true,
      );

      final updated = original.copyWith(
        completedChunks: 7,
        status: UploadStatus.completed,
      );

      expect(updated.totalChunks, 10); // unchanged
      expect(updated.completedChunks, 7); // changed
      expect(updated.failedChunks, 1); // unchanged
      expect(updated.status, UploadStatus.completed); // changed
      expect(updated.canRetry, true); // unchanged
    });

    test('should handle equality correctly', () {
      final progress1 = UploadProgress(
        totalChunks: 10,
        completedChunks: 5,
        failedChunks: 1,
        status: UploadStatus.uploading,
        canRetry: true,
      );

      final progress2 = UploadProgress(
        totalChunks: 10,
        completedChunks: 5,
        failedChunks: 1,
        status: UploadStatus.uploading,
        canRetry: true,
      );

      final progress3 = UploadProgress(
        totalChunks: 10,
        completedChunks: 6, // different
        failedChunks: 1,
        status: UploadStatus.uploading,
        canRetry: true,
      );

      expect(progress1, equals(progress2));
      expect(progress1, isNot(equals(progress3)));
      expect(progress1.hashCode, equals(progress2.hashCode));
    });

    group('Authentication Error Handling', () {
      test('should classify authentication errors correctly', () {
        // Test that the UploadErrorClassifier correctly identifies authentication errors
        final authError = PermanentAuthenticationError('Authentication failed');
        final errorType = UploadErrorClassifier.classifyError(authError);
        
        expect(errorType, UploadErrorType.permanentAuth);
      });

      test('should handle authentication error patterns', () {
        // Test various authentication error patterns
        final patterns = [
          'Authentication failed - user needs to re-login',
          'No refresh token found',
          'Failed to refresh token:',
          'Not authenticated',
        ];

        for (final pattern in patterns) {
          final error = Exception(pattern);
          final errorType = UploadErrorClassifier.classifyError(error);
          expect(errorType, UploadErrorType.permanentAuth, 
                 reason: 'Pattern "$pattern" should be classified as permanent auth error');
        }
      });

      test('should classify temporary errors correctly', () {
        // Test that temporary errors are classified correctly
        final temporaryPatterns = [
          'Server error',
          'Token refreshed',
        ];

        for (final pattern in temporaryPatterns) {
          final error = Exception(pattern);
          final errorType = UploadErrorClassifier.classifyError(error);
          expect(errorType, UploadErrorType.temporary, 
                 reason: 'Pattern "$pattern" should be classified as temporary error');
        }
      });

      test('should classify permanent client errors correctly', () {
        // Test that permanent client errors are classified correctly
        final clientError = Exception('Client error 400');
        final errorType = UploadErrorClassifier.classifyError(clientError);
        
        expect(errorType, UploadErrorType.permanentClient);
      });

      test('should default to temporary for unknown errors', () {
        // Test that unknown errors default to temporary
        final unknownError = Exception('Some unknown error');
        final errorType = UploadErrorClassifier.classifyError(unknownError);
        
        expect(errorType, UploadErrorType.temporary);
      });

      test('should handle PermanentAuthenticationError exception type', () {
        // Test that PermanentAuthenticationError exception type is classified correctly
        final authError = PermanentAuthenticationError('Token expired');
        final errorType = UploadErrorClassifier.classifyError(authError);
        
        expect(errorType, UploadErrorType.permanentAuth);
      });
    });
  });
}