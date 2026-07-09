import 'dart:async';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/isar_service.dart';

/// Service for managing export progress and emitting progress updates
class ExportProgressService {
  static const String exportLoginRequiredErrorToken =
      'EXPORT_LOGIN_REQUIRED';

  final IsarService isarService;
  final int trackId;
  final bool isOpenSourceMapCompatible;

  late final StreamController<UploadProgress> _progressController;
  bool _isCancelled = false;
  int _currentTotalChunks = 0;
  int _currentCompletedChunks = 0;

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

      final String csvFilePath;

      if (isOpenSourceMapCompatible) {
        csvFilePath = await isarService.exportTrackToCsvInOpenSenseMapFormat(
          trackId,
          onChunkPlan: _emitChunkPlan,
          onChunkProgress: _emitChunkProgress,
        );
      } else {
        csvFilePath = await isarService.exportTrackToCsv(
          trackId,
          onChunkPlan: _emitChunkPlan,
          onChunkProgress: _emitChunkProgress,
        );
      }

      if (!_isCancelled) {
        // Emit completed state while preserving actual chunk totals.
        final totalChunks = _currentTotalChunks <= 0 ? 1 : _currentTotalChunks;
        final completedChunks = totalChunks;
        _progressController.add(
          UploadProgress(
            totalChunks: totalChunks,
            completedChunks: completedChunks,
            failedChunks: 0,
            status: UploadStatus.completed,
            errorMessage: null,
            canRetry: false,
          ),
        );
      }

      return csvFilePath;
    } catch (e) {
      if (!_isCancelled) {
        _progressController.add(
          UploadProgress(
            totalChunks: _currentTotalChunks <= 0 ? 1 : _currentTotalChunks,
            completedChunks: _currentCompletedChunks,
            failedChunks: 1,
            status: UploadStatus.failed,
            // Use a dedicated token so the existing modal can render
            // a specific localized export-authentication message.
            errorMessage: exportLoginRequiredErrorToken,
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
          totalChunks: _currentTotalChunks,
          completedChunks: _currentTotalChunks > 0
              ? (progressValue == 1.0 ? _currentTotalChunks : 0)
              : 0,
          failedChunks: 0,
          status: status,
          errorMessage: null,
          canRetry: false,
        ),
      );
    }
  }

  void _emitChunkProgress(int completedChunks, int totalChunks) {
    if (_isCancelled || _progressController.isClosed) return;
    _currentTotalChunks = totalChunks <= 0 ? 0 : totalChunks;
    _currentCompletedChunks = completedChunks.clamp(0, _currentTotalChunks);
    _progressController.add(
      UploadProgress(
        totalChunks: _currentTotalChunks,
        completedChunks: _currentCompletedChunks,
        failedChunks: 0,
        status: UploadStatus.uploading,
        errorMessage: null,
        canRetry: false,
      ),
    );
  }

  void _emitChunkPlan(int totalChunks) {
    if (_isCancelled || _progressController.isClosed) return;
    _currentTotalChunks = totalChunks <= 0 ? 0 : totalChunks;
    _currentCompletedChunks = 0;
    _progressController.add(
      UploadProgress(
        totalChunks: _currentTotalChunks,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.uploading,
        errorMessage: null,
        canRetry: false,
      ),
    );
  }
}
