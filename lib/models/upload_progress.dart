enum UploadStatus { preparing, uploading, completed, failed, retrying }

enum UploadFailureKind { authentication, connection, apiResponse, other }

enum UploadStage { checkingLogin, uploadingPart }

class UploadProgress {
  final UploadStatus status;
  final int totalChunks;
  final int completedChunks;
  final UploadStage? stage;
  final String? errorMessage;
  final String? errorDetail;
  final UploadFailureKind? failureKind;

  const UploadProgress({
    required this.status,
    this.totalChunks = 0,
    this.completedChunks = 0,
    this.stage,
    this.errorMessage,
    this.errorDetail,
    this.failureKind,
  });

  double get progressPercentage =>
      totalChunks == 0 ? 0.0 : completedChunks / totalChunks;

  bool get isInProgress =>
      status == UploadStatus.uploading || status == UploadStatus.retrying;

  bool get isCompleted => status == UploadStatus.completed;

  bool get hasFailed => status == UploadStatus.failed;
}
