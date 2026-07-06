import 'dart:async';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/isar_service.dart';

/// Service for managing export progress and emitting progress updates
class ExportProgressService {
  final IsarService isarService;
  final int trackId;
  final bool isOpenSourceMapCompatible;

  late final StreamController<UploadProgress> _progressController;
  bool _isCancelled = false;

  ExportProgressService({
    required this.isarService,
    required this.trackId,
    required this.isOpenSourceMapCompatible,
  });

  Stream<UploadProgress> get progressStream => _progressController.stream;

  void initialize() {
    _progressController = StreamController<UploadProgress>.broadcast();
  }

  Future<String> startExport() async {
    try {
      // Emit preparing state
      _emitProgress(UploadStatus.preparing, 0);
      _emitProgress(UploadStatus.uploading, 0);

      final String csvFilePath;

      if (isOpenSourceMapCompatible) {
        csvFilePath = await isarService
            .exportTrackToCsvInOpenSenseMapFormat(trackId);
      } else {
        csvFilePath = await isarService.exportTrackToCsv(trackId);
      }

      if (!_isCancelled) {
        // Emit completed state
        _emitProgress(UploadStatus.completed, 1.0);
      }

      return csvFilePath;
    } catch (e) {
      if (!_isCancelled) {
        _progressController.add(
          UploadProgress(
            totalChunks: 1,
            completedChunks: 0,
            failedChunks: 1,
            status: UploadStatus.failed,
            errorMessage: e.toString(),
            canRetry: false,
          ),
        );
      }
      rethrow;
    }
  }

  void cancel() {
    _isCancelled = true;
  }

  void dispose() {
    _progressController.close();
  }

  void _emitProgress(UploadStatus status, double progressValue) {
    if (!_isCancelled && !_progressController.isClosed) {
      _progressController.add(
        UploadProgress(
          totalChunks: 1,
          completedChunks: progressValue == 1.0 ? 1 : 0,
          failedChunks: 0,
          status: status,
          errorMessage: null,
          canRetry: false,
        ),
      );
    }
  }
}
