import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/models/chunk_upload_result.dart';

void main() {
  group('Upload Models Integration', () {
    test('should work together in realistic upload scenario', () {
      // Simulate a track upload with 3 chunks
      const totalChunks = 3;
      
      // Initial progress - preparing
      var progress = const UploadProgress(
        totalChunks: totalChunks,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.preparing,
        canRetry: false,
      );
      
      expect(progress.status, equals(UploadStatus.preparing));
      expect(progress.progressPercentage, equals(0.0));
      expect(progress.isInProgress, isFalse);
      
      // Start uploading
      progress = progress.copyWith(status: UploadStatus.uploading);
      expect(progress.isInProgress, isTrue);
      
      // First chunk succeeds
      final chunk1Result = ChunkUploadResult.success(0);
      expect(chunk1Result.success, isTrue);
      expect(chunk1Result.chunkIndex, equals(0));
      
      progress = progress.copyWith(completedChunks: 1);
      expect(progress.progressPercentage, closeTo(0.33, 0.01));
      
      // Second chunk fails with retryable error
      final chunk2Result = ChunkUploadResult.retryableFailure(
        1,
        'Network timeout',
      );
      expect(chunk2Result.failed, isTrue);
      expect(chunk2Result.isRetryable, isTrue);
      
      progress = progress.copyWith(
        failedChunks: 1,
        status: UploadStatus.retrying,
        errorMessage: 'Retrying failed chunks',
      );
      expect(progress.isInProgress, isTrue);
      expect(progress.hasFailed, isFalse); // Still retrying
      
      // Retry succeeds
      final chunk2RetryResult = ChunkUploadResult.success(1);
      expect(chunk2RetryResult.success, isTrue);
      
      progress = progress.copyWith(
        completedChunks: 2,
        failedChunks: 0,
        status: UploadStatus.uploading,
        errorMessage: null,
      );
      expect(progress.progressPercentage, closeTo(0.67, 0.01));
      
      // Third chunk succeeds
      final chunk3Result = ChunkUploadResult.success(2);
      expect(chunk3Result.success, isTrue);
      
      progress = progress.copyWith(
        completedChunks: 3,
        status: UploadStatus.completed,
      );
      
      expect(progress.isCompleted, isTrue);
      expect(progress.progressPercentage, equals(1.0));
      expect(progress.progressPercentageInt, equals(100));
      expect(progress.isInProgress, isFalse);
      expect(progress.hasFailed, isFalse);
    });

    test('should handle permanent failure scenario', () {
      // Simulate authentication failure
      const progress = UploadProgress(
        totalChunks: 5,
        completedChunks: 2,
        failedChunks: 3,
        status: UploadStatus.failed,
        errorMessage: 'Authentication failed',
        canRetry: false,
      );
      
      final chunkResult = ChunkUploadResult.permanentFailure(
        2,
        'Authentication failed',
      );
      
      expect(progress.hasFailed, isTrue);
      expect(progress.canRetry, isFalse);
      expect(chunkResult.failed, isTrue);
      expect(chunkResult.isRetryable, isFalse);
      expect(progress.progressPercentage, equals(0.4)); // 2/5
    });

    test('should handle edge cases', () {
      // Empty upload
      const emptyProgress = UploadProgress(
        totalChunks: 0,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.completed,
        canRetry: false,
      );
      
      expect(emptyProgress.progressPercentage, equals(0.0));
      expect(emptyProgress.progressPercentageInt, equals(0));
      
      // Large chunk index
      final largeIndexResult = ChunkUploadResult.success(999999);
      expect(largeIndexResult.chunkIndex, equals(999999));
      expect(largeIndexResult.success, isTrue);
    });
  });
}