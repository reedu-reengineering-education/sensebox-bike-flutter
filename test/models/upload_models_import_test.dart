import 'package:flutter_test/flutter_test.dart';

// Test that both models can be imported together
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/models/chunk_upload_result.dart';

void main() {
  test('should be able to import both upload models', () {
    // This test verifies that both models can be imported without conflicts
    
    // Create instances to verify they work
    const progress = UploadProgress(
      totalChunks: 1,
      completedChunks: 0,
      failedChunks: 0,
      status: UploadStatus.preparing,
      canRetry: false,
    );
    
    final result = ChunkUploadResult.success(0);
    
    // Basic verification
    expect(progress, isA<UploadProgress>());
    expect(result, isA<ChunkUploadResult>());
    expect(UploadStatus.values, hasLength(5));
  });
}