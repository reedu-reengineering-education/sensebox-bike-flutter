import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/upload_progress.dart';

void main() {
  group('UploadStatus', () {
    test('should have all required enum values', () {
      expect(UploadStatus.values, hasLength(5));
      expect(UploadStatus.values, contains(UploadStatus.preparing));
      expect(UploadStatus.values, contains(UploadStatus.uploading));
      expect(UploadStatus.values, contains(UploadStatus.completed));
      expect(UploadStatus.values, contains(UploadStatus.failed));
      expect(UploadStatus.values, contains(UploadStatus.retrying));
    });
  });

  group('UploadProgress', () {
    test('should create instance with required properties', () {
      const progress = UploadProgress(
        totalChunks: 10,
        completedChunks: 5,
        failedChunks: 1,
        status: UploadStatus.uploading,
        canRetry: true,
      );

      expect(progress.totalChunks, equals(10));
      expect(progress.completedChunks, equals(5));
      expect(progress.failedChunks, equals(1));
      expect(progress.status, equals(UploadStatus.uploading));
      expect(progress.errorMessage, isNull);
      expect(progress.canRetry, isTrue);
    });

    test('should create instance with error message', () {
      const progress = UploadProgress(
        totalChunks: 5,
        completedChunks: 2,
        failedChunks: 1,
        status: UploadStatus.failed,
        errorMessage: 'Network error',
        canRetry: true,
      );

      expect(progress.errorMessage, equals('Network error'));
    });

    group('progressPercentage', () {
      test('should calculate correct percentage', () {
        const progress = UploadProgress(
          totalChunks: 10,
          completedChunks: 3,
          failedChunks: 0,
          status: UploadStatus.uploading,
          canRetry: true,
        );

        expect(progress.progressPercentage, equals(0.3));
      });

      test('should return 0.0 when totalChunks is 0', () {
        const progress = UploadProgress(
          totalChunks: 0,
          completedChunks: 0,
          failedChunks: 0,
          status: UploadStatus.preparing,
          canRetry: false,
        );

        expect(progress.progressPercentage, equals(0.0));
      });

      test('should return 1.0 when all chunks completed', () {
        const progress = UploadProgress(
          totalChunks: 5,
          completedChunks: 5,
          failedChunks: 0,
          status: UploadStatus.completed,
          canRetry: false,
        );

        expect(progress.progressPercentage, equals(1.0));
      });
    });

    group('progressPercentageInt', () {
      test('should return integer percentage', () {
        const progress = UploadProgress(
          totalChunks: 10,
          completedChunks: 3,
          failedChunks: 0,
          status: UploadStatus.uploading,
          canRetry: true,
        );

        expect(progress.progressPercentageInt, equals(30));
      });

      test('should round to nearest integer', () {
        const progress = UploadProgress(
          totalChunks: 3,
          completedChunks: 1,
          failedChunks: 0,
          status: UploadStatus.uploading,
          canRetry: true,
        );

        // 1/3 = 0.333... which rounds to 33
        expect(progress.progressPercentageInt, equals(33));
      });
    });

    group('status helpers', () {
      test('isInProgress should return true for uploading status', () {
        const progress = UploadProgress(
          totalChunks: 5,
          completedChunks: 2,
          failedChunks: 0,
          status: UploadStatus.uploading,
          canRetry: true,
        );

        expect(progress.isInProgress, isTrue);
        expect(progress.isCompleted, isFalse);
        expect(progress.hasFailed, isFalse);
      });

      test('isInProgress should return true for retrying status', () {
        const progress = UploadProgress(
          totalChunks: 5,
          completedChunks: 2,
          failedChunks: 1,
          status: UploadStatus.retrying,
          canRetry: true,
        );

        expect(progress.isInProgress, isTrue);
        expect(progress.isCompleted, isFalse);
        expect(progress.hasFailed, isFalse);
      });

      test('isCompleted should return true for completed status', () {
        const progress = UploadProgress(
          totalChunks: 5,
          completedChunks: 5,
          failedChunks: 0,
          status: UploadStatus.completed,
          canRetry: false,
        );

        expect(progress.isInProgress, isFalse);
        expect(progress.isCompleted, isTrue);
        expect(progress.hasFailed, isFalse);
      });

      test('hasFailed should return true for failed status', () {
        const progress = UploadProgress(
          totalChunks: 5,
          completedChunks: 2,
          failedChunks: 3,
          status: UploadStatus.failed,
          errorMessage: 'Upload failed',
          canRetry: true,
        );

        expect(progress.isInProgress, isFalse);
        expect(progress.isCompleted, isFalse);
        expect(progress.hasFailed, isTrue);
      });

      test('should return false for all helpers when preparing', () {
        const progress = UploadProgress(
          totalChunks: 5,
          completedChunks: 0,
          failedChunks: 0,
          status: UploadStatus.preparing,
          canRetry: false,
        );

        expect(progress.isInProgress, isFalse);
        expect(progress.isCompleted, isFalse);
        expect(progress.hasFailed, isFalse);
      });
    });

    group('copyWith', () {
      test('should create copy with updated values', () {
        const original = UploadProgress(
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

        expect(updated.totalChunks, equals(10)); // unchanged
        expect(updated.completedChunks, equals(7)); // updated
        expect(updated.failedChunks, equals(1)); // unchanged
        expect(updated.status, equals(UploadStatus.completed)); // updated
        expect(updated.canRetry, isTrue); // unchanged
      });

      test('should create copy with error message', () {
        const original = UploadProgress(
          totalChunks: 5,
          completedChunks: 2,
          failedChunks: 0,
          status: UploadStatus.uploading,
          canRetry: true,
        );

        final updated = original.copyWith(
          status: UploadStatus.failed,
          errorMessage: 'Network timeout',
        );

        expect(updated.status, equals(UploadStatus.failed));
        expect(updated.errorMessage, equals('Network timeout'));
      });
    });

    group('equality and hashCode', () {
      test('should be equal when all properties match', () {
        const progress1 = UploadProgress(
          totalChunks: 10,
          completedChunks: 5,
          failedChunks: 1,
          status: UploadStatus.uploading,
          errorMessage: 'test error',
          canRetry: true,
        );

        const progress2 = UploadProgress(
          totalChunks: 10,
          completedChunks: 5,
          failedChunks: 1,
          status: UploadStatus.uploading,
          errorMessage: 'test error',
          canRetry: true,
        );

        expect(progress1, equals(progress2));
        expect(progress1.hashCode, equals(progress2.hashCode));
      });

      test('should not be equal when properties differ', () {
        const progress1 = UploadProgress(
          totalChunks: 10,
          completedChunks: 5,
          failedChunks: 1,
          status: UploadStatus.uploading,
          canRetry: true,
        );

        const progress2 = UploadProgress(
          totalChunks: 10,
          completedChunks: 6, // different
          failedChunks: 1,
          status: UploadStatus.uploading,
          canRetry: true,
        );

        expect(progress1, isNot(equals(progress2)));
      });
    });

    group('toString', () {
      test('should return formatted string representation', () {
        const progress = UploadProgress(
          totalChunks: 10,
          completedChunks: 5,
          failedChunks: 1,
          status: UploadStatus.uploading,
          errorMessage: 'test error',
          canRetry: true,
        );

        final string = progress.toString();
        expect(string, contains('UploadProgress('));
        expect(string, contains('totalChunks: 10'));
        expect(string, contains('completedChunks: 5'));
        expect(string, contains('failedChunks: 1'));
        expect(string, contains('status: UploadStatus.uploading'));
        expect(string, contains('errorMessage: test error'));
        expect(string, contains('canRetry: true'));
      });
    });
  });
}