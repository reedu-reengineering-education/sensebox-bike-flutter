/// Upload status enumeration for tracking different states of upload operations
enum UploadStatus {
  /// Initial state when preparing data for upload
  preparing,
  
  /// Upload is currently in progress
  uploading,
  
  /// Upload has completed successfully
  completed,
  
  /// Upload has failed
  failed,
  
  /// Upload is being retried after a failure
  retrying,
}

/// Model representing the progress of a track upload operation
class UploadProgress {
  /// Total number of chunks to be uploaded
  final int totalChunks;
  
  /// Number of chunks that have been successfully uploaded
  final int completedChunks;
  
  /// Number of chunks that have failed to upload
  final int failedChunks;
  
  /// Current status of the upload operation
  final UploadStatus status;
  
  /// Error message if upload failed, null otherwise
  final String? errorMessage;
  
  /// Whether the upload can be retried
  final bool canRetry;

  const UploadProgress({
    required this.totalChunks,
    required this.completedChunks,
    required this.failedChunks,
    required this.status,
    this.errorMessage,
    required this.canRetry,
  });

  /// Calculate the progress percentage (0.0 to 1.0)
  double get progressPercentage {
    if (totalChunks == 0) return 0.0;
    return completedChunks / totalChunks;
  }

  /// Get the progress percentage as an integer (0 to 100)
  int get progressPercentageInt {
    return (progressPercentage * 100).round();
  }

  /// Check if the upload is in progress
  bool get isInProgress {
    return status == UploadStatus.uploading || status == UploadStatus.retrying;
  }

  /// Check if the upload has completed successfully
  bool get isCompleted {
    return status == UploadStatus.completed;
  }

  /// Check if the upload has failed
  bool get hasFailed {
    return status == UploadStatus.failed;
  }

  /// Create a copy of this UploadProgress with updated values
  UploadProgress copyWith({
    int? totalChunks,
    int? completedChunks,
    int? failedChunks,
    UploadStatus? status,
    String? errorMessage,
    bool? canRetry,
  }) {
    return UploadProgress(
      totalChunks: totalChunks ?? this.totalChunks,
      completedChunks: completedChunks ?? this.completedChunks,
      failedChunks: failedChunks ?? this.failedChunks,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      canRetry: canRetry ?? this.canRetry,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UploadProgress &&
        other.totalChunks == totalChunks &&
        other.completedChunks == completedChunks &&
        other.failedChunks == failedChunks &&
        other.status == status &&
        other.errorMessage == errorMessage &&
        other.canRetry == canRetry;
  }

  @override
  int get hashCode {
    return Object.hash(
      totalChunks,
      completedChunks,
      failedChunks,
      status,
      errorMessage,
      canRetry,
    );
  }

  @override
  String toString() {
    return 'UploadProgress('
        'totalChunks: $totalChunks, '
        'completedChunks: $completedChunks, '
        'failedChunks: $failedChunks, '
        'status: $status, '
        'errorMessage: $errorMessage, '
        'canRetry: $canRetry)';
  }
}