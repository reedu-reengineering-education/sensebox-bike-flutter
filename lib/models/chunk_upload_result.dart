/// Model representing the result of uploading a single chunk of data
class ChunkUploadResult {
  /// Whether the chunk upload was successful
  final bool success;
  
  /// Error message if upload failed, null if successful
  final String? errorMessage;
  
  /// Whether this error is retryable (temporary error vs permanent error)
  final bool isRetryable;
  
  /// Index of the chunk that was uploaded (0-based)
  final int chunkIndex;

  /// Original error that caused the failure, if any. Lets callers classify
  /// the failure (network vs. API response) without parsing [errorMessage].
  final Object? error;

  const ChunkUploadResult({
    required this.success,
    this.errorMessage,
    required this.isRetryable,
    required this.chunkIndex,
    this.error,
  });

  /// Create a successful chunk upload result
  factory ChunkUploadResult.success(int chunkIndex) {
    return ChunkUploadResult(
      success: true,
      errorMessage: null,
      isRetryable: false,
      chunkIndex: chunkIndex,
    );
  }

  /// Create a failed chunk upload result with retryable error
  factory ChunkUploadResult.retryableFailure(
    int chunkIndex,
    String errorMessage, {
    Object? error,
  }) {
    return ChunkUploadResult(
      success: false,
      errorMessage: errorMessage,
      isRetryable: true,
      chunkIndex: chunkIndex,
      error: error,
    );
  }

  /// Create a failed chunk upload result with permanent error
  factory ChunkUploadResult.permanentFailure(
    int chunkIndex,
    String errorMessage, {
    Object? error,
  }) {
    return ChunkUploadResult(
      success: false,
      errorMessage: errorMessage,
      isRetryable: false,
      chunkIndex: chunkIndex,
      error: error,
    );
  }

  /// Check if the upload failed
  bool get failed => !success;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChunkUploadResult &&
        other.success == success &&
        other.errorMessage == errorMessage &&
        other.isRetryable == isRetryable &&
        other.chunkIndex == chunkIndex;
  }

  @override
  int get hashCode {
    return Object.hash(success, errorMessage, isRetryable, chunkIndex);
  }

  @override
  String toString() {
    return 'ChunkUploadResult('
        'success: $success, '
        'errorMessage: $errorMessage, '
        'isRetryable: $isRetryable, '
        'chunkIndex: $chunkIndex)';
  }
}