import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/chunked_uploader.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/upload_error_classifier.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';

class BatchUploadService {
  static const String authenticationFailedMessage =
      'Authentication failed. Please log in again to upload your tracks.';

  static const Duration defaultChunkUploadTimeout = Duration(seconds: 60);
  static const Duration _authValidationTimeout = Duration(seconds: 15);

  final OpenSenseMapService _openSenseMapService;
  final TrackService _trackService;
  final OpenSenseMapBloc _openSenseMapBloc;

  /// Hard limit for uploading a single chunk, including its retry.
  final Duration chunkUploadTimeout;

  final StreamController<UploadProgress> _progressController =
      StreamController<UploadProgress>.broadcast();

  Completer<void>? _cancelSignal;
  bool _isUploading = false;
  int _totalChunks = 0;
  int _completedChunks = 0;

  BatchUploadService({
    required OpenSenseMapService openSenseMapService,
    required TrackService trackService,
    required OpenSenseMapBloc openSenseMapBloc,
    this.chunkUploadTimeout = defaultChunkUploadTimeout,
  })  : _openSenseMapService = openSenseMapService,
        _trackService = trackService,
        _openSenseMapBloc = openSenseMapBloc;

  Stream<UploadProgress> get uploadProgressStream => _progressController.stream;

  bool get isUploading => _isUploading;

  /// Stops at the first chunk that fails and rethrows its error.
  /// Returns normally when cancelled via [cancelUpload].
  Future<void> uploadTrack(TrackData track, SenseBox senseBox) async {
    if (_isUploading) {
      final error = Exception('Another upload is already in progress');
      unawaited(ErrorService.reportToSentry(error, StackTrace.current));
      throw error;
    }

    _isUploading = true;
    _totalChunks = 0;
    _completedChunks = 0;
    final cancelSignal = Completer<void>();
    _cancelSignal = cancelSignal;
    _log('Upload of track ${track.id} started');

    try {
      track.uploadAttempts = (track.uploadAttempts ?? 0) + 1;
      track.lastUploadAttempt = DateTime.now();
      await _trackService.saveTrack(track);

      _emit(UploadStatus.preparing, stage: UploadStage.checkingLogin);
      await _untilCancelled(_waitForAuthentication());

      _emit(UploadStatus.preparing, stage: UploadStage.loadingTrack);
      await _untilCancelled(track.geolocations.load());
      final geolocations = track.geolocations.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (geolocations.isEmpty) {
        _log('Track ${track.id} has no points, nothing to upload');
        _emit(UploadStatus.completed);
        return;
      }

      final chunkedUploader = ChunkedUploader(
        openSenseMapService: _openSenseMapService,
        senseBox: senseBox,
      );
      final chunks = chunkedUploader.splitIntoChunks(geolocations);
      _totalChunks = chunks.length;
      _log('Track ${track.id}: ${geolocations.length} points in '
          '$_totalChunks chunks');

      for (final chunk in chunks) {
        await _uploadChunk(chunkedUploader, chunk, cancelSignal);
        _completedChunks++;
      }

      track.uploaded = 1;
      await _trackService.saveTrack(track);
      _emit(UploadStatus.completed);
      _log('Upload of track ${track.id} completed');
    } on UploadCancelledException {
      // A request already in flight may still reach the server.
      _log('Upload of track ${track.id} cancelled');
    } catch (e, stackTrace) {
      await _fail(track, e, stackTrace);
      rethrow;
    } finally {
      _isUploading = false;
      if (identical(_cancelSignal, cancelSignal)) _cancelSignal = null;
    }
  }

  void cancelUpload() {
    final signal = _cancelSignal;
    if (signal == null || signal.isCompleted) return;
    _log('Cancel requested');
    signal.complete();
  }

  void dispose() {
    cancelUpload();
    _progressController.close();
  }

  /// Work that was given up on (timeout, cancel) keeps running in the
  /// background; [isActive] stops it from reporting progress or sending.
  Future<void> _uploadChunk(
    ChunkedUploader uploader,
    List<GeolocationData> chunk,
    Completer<void> cancelSignal,
  ) async {
    var abandoned = false;
    bool isActive() => !abandoned && !cancelSignal.isCompleted;
    void emitIfActive(UploadStatus status, UploadStage stage) {
      if (isActive()) _emit(status, stage: stage);
    }

    emitIfActive(UploadStatus.uploading, UploadStage.preparingChunk);
    try {
      await _untilCancelled(uploader
          .uploadChunk(
            chunk,
            shouldSend: isActive,
            onSending: () =>
                emitIfActive(UploadStatus.uploading, UploadStage.sendingChunk),
            onRetry: (_) =>
                emitIfActive(UploadStatus.retrying, UploadStage.retryingChunk),
          )
          .timeout(chunkUploadTimeout));
    } finally {
      abandoned = true;
    }
  }

  Future<void> _fail(TrackData track, Object error, StackTrace stackTrace) async {
    _log('Upload of track ${track.id} failed after '
        '$_completedChunks/$_totalChunks chunks: $error');
    unawaited(ErrorService.reportToSentry(
        'Batch upload of track ${track.id} failed: $error', stackTrace));

    final isAuthError = UploadErrorClassifier.classifyError(error) ==
        UploadErrorType.permanentAuth;
    if (isAuthError) {
      try {
        await _openSenseMapBloc.markAuthenticationFailed();
      } catch (e) {
        _log('Could not mark authentication as failed: $e');
      }
    }

    _emit(
      UploadStatus.failed,
      errorMessage: isAuthError ? authenticationFailedMessage : '$error',
      errorDetail: isAuthError ? null : UploadErrorClassifier.describe(error),
      failureKind:
          isAuthError ? null : UploadErrorClassifier.failureKindOf(error),
      canRetry: !isAuthError,
    );
  }

  Future<void> _waitForAuthentication() async {
    final deadline = DateTime.now().add(_authValidationTimeout);
    while (_openSenseMapBloc.isAuthenticating) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
            'Login check did not finish', _authValidationTimeout);
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!_openSenseMapBloc.isAuthenticated) {
      throw PermanentAuthenticationError('Not logged in to openSenseMap');
    }
  }

  /// The underlying work is not aborted, its result is just ignored.
  Future<T> _untilCancelled<T>(Future<T> future) {
    final signal = _cancelSignal;
    if (signal == null) return future;
    if (signal.isCompleted) {
      future.ignore();
      throw const UploadCancelledException();
    }
    return Future.any<T>([
      future,
      signal.future.then<T>((_) => throw const UploadCancelledException()),
    ]);
  }

  void _emit(
    UploadStatus status, {
    UploadStage? stage,
    String? errorMessage,
    String? errorDetail,
    UploadFailureKind? failureKind,
    bool canRetry = false,
  }) {
    // The service may be disposed while an upload is still finishing.
    if (_progressController.isClosed) return;
    _progressController.add(UploadProgress(
      totalChunks: _totalChunks,
      completedChunks:
          status == UploadStatus.completed ? _totalChunks : _completedChunks,
      failedChunks: status == UploadStatus.failed ? 1 : 0,
      status: status,
      stage: stage,
      errorMessage: errorMessage,
      errorDetail: errorDetail,
      failureKind: failureKind,
      canRetry: canRetry,
    ));
  }

  void _log(String message) {
    debugPrint(
        '[${DateTime.now().toIso8601String()}] [BatchUploadService] $message');
  }
}
