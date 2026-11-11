import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/upload_progress.dart';

void main() {
  group('progressPercentage', () {
    test('is the share of completed chunks', () {
      expect(
          const UploadProgress(
                  status: UploadStatus.uploading,
                  totalChunks: 10,
                  completedChunks: 3)
              .progressPercentage,
          0.3);
    });

    test('is 0 without chunks', () {
      expect(const UploadProgress(status: UploadStatus.preparing)
          .progressPercentage, 0.0);
    });
  });

  group('status helpers', () {
    test('uploading and retrying are in progress', () {
      expect(const UploadProgress(status: UploadStatus.uploading).isInProgress,
          isTrue);
      expect(const UploadProgress(status: UploadStatus.retrying).isInProgress,
          isTrue);
      expect(const UploadProgress(status: UploadStatus.preparing).isInProgress,
          isFalse);
    });

    test('completed and failed', () {
      expect(const UploadProgress(status: UploadStatus.completed).isCompleted,
          isTrue);
      expect(
          const UploadProgress(status: UploadStatus.failed).hasFailed, isTrue);
    });
  });
}
