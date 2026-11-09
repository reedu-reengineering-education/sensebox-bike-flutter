import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sensebox_bike/models/chunk_upload_result.dart';
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

/// Service responsible for coordinating batch uploads of complete tracks.
/// 
/// This service handles the complete upload flow:
/// 1. Splits tracks into chunks using ChunkedUploader
/// 2. Uploads chunks, failing fast (see [chunkUploadTimeout])
/// 3. Provides real-time progress updates via stream
/// 4. Updates track status when upload completes
/// 5. Handles authentication failures and other errors
class BatchUploadService {
  /// [UploadProgress.errorMessage] when a chunk could not be uploaded and the
  /// user should try again later. [UploadProgress.errorDetail] holds the
  /// actual reason, [UploadProgress.failureKind] what kind of failure it was.
  static const String uploadFailedTryLaterErrorToken =
      'batch_upload_failed_try_later';


  static const Duration defaultChunkUploadTimeout = Duration(seconds: 60);

  final OpenSenseMapService _openSenseMapService;
  final TrackService _trackService;
  final OpenSenseMapBloc _openSenseMapBloc;

  /// Hard limit for uploading a single chunk, including its retry.
  final Duration chunkUploadTimeout;

  Completer<void>? _cancelSignal;
  
  // Progress stream controller for real-time upload status
  final StreamController<UploadProgress> _progressController = 
      StreamController<UploadProgress>.broadcast();
  
  // Current upload state
  UploadProgress? _currentProgress;
  bool _isUploading = false;

  BatchUploadService({
    required OpenSenseMapService openSenseMapService,
    required TrackService trackService,
    required OpenSenseMapBloc openSenseMapBloc,
    this.chunkUploadTimeout = defaultChunkUploadTimeout,
  })  : _openSenseMapService = openSenseMapService,
        _trackService = trackService,
        _openSenseMapBloc = openSenseMapBloc;

  /// Stream of upload progress updates
  Stream<UploadProgress> get uploadProgressStream => _progressController.stream;

  /// Current upload progress, null if no upload in progress
  UploadProgress? get currentProgress => _currentProgress;

  /// Whether an upload is currently in progress
  bool get isUploading => _isUploading;

  /// Waits for authentication validation to complete before proceeding with upload.
  /// This prevents authentication errors when the app resumes from background
  /// and authentication validation is still in progress.
  ///
  /// [timeoutSeconds] - Maximum time to wait for authentication validation (default: 15 seconds)
  ///
  /// Throws [Exception] if authentication validation times out or fails
  Future<void> _waitForAuthenticationValidation(
      {int timeoutSeconds = 15}) async {
    _logInfo('Authentication wait',
        'Waiting for authentication validation to complete', null);

    final startTime = DateTime.now();
    final timeout = Duration(seconds: timeoutSeconds);

    while (_openSenseMapBloc.isAuthenticating) {
      // Check if we've exceeded the timeout
      if (DateTime.now().difference(startTime) > timeout) {
        const errorMessage = 'Authentication validation timed out';
        _logError('Authentication timeout', errorMessage, null);
        throw Exception(errorMessage);
      }

      // Wait a short interval before checking again
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Final authentication check after validation completes
    if (!_openSenseMapBloc.isAuthenticated) {
      const errorMessage = 'Authentication validation failed';
      _logError('Authentication validation failed', errorMessage, null);
      throw Exception(errorMessage);
    }

    _logInfo('Authentication wait',
        'Authentication validation completed successfully', null);
  }

  /// Uploads a complete track by splitting it into chunks and uploading them
  /// sequentially.
  ///
  /// The user is watching a progress modal, so the upload fails fast: each
  /// chunk gets at most [chunkUploadTimeout] (including one quick retry inside
  /// [ChunkedUploader]). The first chunk that cannot be uploaded stops the
  /// whole track and emits a failed status with the API's error message or a
  /// "could not connect" detail. The track is not marked uploaded, so the
  /// user can try again later.
  ///
  /// The upload can be stopped with [cancelUpload]. A cancelled upload
  /// returns normally without marking the track as uploaded.
  ///
  /// Throws if the upload fails.
  Future<void> uploadTrack(TrackData track, SenseBox senseBox) async {
    if (_isUploading) {
      const errorMessage = 'Another upload is already in progress';
      _logError('Upload attempt blocked', errorMessage, track.id);
      throw Exception(errorMessage);
    }

    _isUploading = true;
    final cancelSignal = Completer<void>();
    _cancelSignal = cancelSignal;
    _logInfo('Starting upload', 'Track ${track.id} upload initiated', track.id);

    try {
      track.uploadAttempts = (track.uploadAttempts ?? 0) + 1;
      track.lastUploadAttempt = DateTime.now();
      await _trackService.saveTrack(track);
      _logInfo('Upload attempt tracked',
          'Attempt ${track.uploadAttempts} for track ${track.id}', track.id);

      _updateProgress(const UploadProgress(
        totalChunks: 0,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.preparing,
        canRetry: false,
        stage: UploadStage.checkingLogin,
      ));

      await _untilCancelled(_waitForAuthenticationValidation());

      if (!_openSenseMapBloc.isAuthenticated) {
        const errorMessage = 'Authentication failed - user needs to re-login';
        _logError('Authentication check failed', errorMessage, track.id);
        await _handleAuthenticationError(errorMessage);
        throw Exception(_getAuthenticationErrorMessage(errorMessage));
      }

      final chunkedUploader = ChunkedUploader(
        openSenseMapService: _openSenseMapService,
        senseBox: senseBox,
      );

      _updateProgress(const UploadProgress(
        totalChunks: 0,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.preparing,
        canRetry: false,
        stage: UploadStage.loadingTrack,
      ));

      try {
        await _untilCancelled(track.geolocations.load());
      } on UploadCancelledException {
        rethrow;
      } catch (e, stackTrace) {
        const errorMessage = 'Failed to load track geolocation data';
        _logError('Data loading failed', '$errorMessage: $e', track.id);
        ErrorService.handleError(
          '$errorMessage for track ${track.id}: $e',
          stackTrace,
          sendToSentry: true,
        );
        throw Exception('$errorMessage. Data preserved locally for retry.');
      }

      final geolocations = track.geolocations.toList();

      if (geolocations.isEmpty) {
        _logInfo('Empty track',
            'No geolocation data found for track ${track.id}', track.id);
        _updateProgress(const UploadProgress(
          totalChunks: 0,
          completedChunks: 0,
          failedChunks: 0,
          status: UploadStatus.completed,
          canRetry: false,
        ));
        return;
      }

      geolocations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final chunks = chunkedUploader.splitIntoChunks(geolocations, senseBox);
      final totalChunks = chunks.length;

      _logInfo(
          'Upload preparation complete',
          'Track ${track.id} split into $totalChunks chunks (${geolocations.length} total points)',
          track.id);

      for (int i = 0; i < chunks.length; i++) {
        _logInfo('Chunk upload start',
            'Starting upload of chunk $i/$totalChunks for track ${track.id}',
            track.id);

        var abandoned = false;
        bool isActive() => !abandoned && !cancelSignal.isCompleted;
        void emitStage(UploadStage stage, UploadStatus status) {
          // Abandoned chunks may still report late; ignore them.
          if (!isActive()) return;
          _updateProgress(UploadProgress(
            totalChunks: totalChunks,
            completedChunks: i,
            failedChunks: 0,
            status: status,
            canRetry: false,
            stage: stage,
          ));
        }

        emitStage(UploadStage.preparingChunk, UploadStatus.uploading);

        ChunkUploadResult result;
        try {
          result = await _untilCancelled(chunkedUploader
              .uploadChunk(
                chunks[i],
                senseBox,
                i,
                shouldSend: isActive,
                onSending: () => emitStage(
                    UploadStage.sendingChunk, UploadStatus.uploading),
                onRetry: (_) => emitStage(
                    UploadStage.retryingChunk, UploadStatus.retrying),
              )
              .timeout(chunkUploadTimeout));
        } on TimeoutException catch (e) {
          abandoned = true;
          result = ChunkUploadResult.retryableFailure(
            i,
            'Chunk $i did not finish within ${chunkUploadTimeout.inSeconds}s',
            error: e,
          );
        }

        if (result.failed) {
          _failTrackUpload(track, result, i, totalChunks);
        }

        _logInfo('Chunk upload success',
            'Successfully uploaded chunk $i of track ${track.id}', track.id);
      }

      track.uploaded = 1;
      await _trackService.saveTrack(track);

      _updateProgress(UploadProgress(
        totalChunks: totalChunks,
        completedChunks: totalChunks,
        failedChunks: 0,
        status: UploadStatus.completed,
        canRetry: false,
      ));

      _logInfo('Upload success',
          'Successfully uploaded track ${track.id} with all $totalChunks chunks',
          track.id);
    } on UploadCancelledException {
      // The user closed the modal. The track stays not uploaded; nothing to
      // show. A request already in flight may still reach the server.
      _logInfo('Upload cancelled',
          'Upload of track ${track.id} cancelled by user', track.id);
    } on BatchUploadException catch (e, stackTrace) {
      _logError('Upload failed', e.toString(), track.id);
      unawaited(ErrorService.reportToSentry(
          'Batch upload of track ${track.id} failed: $e', stackTrace));

      _updateProgress(UploadProgress(
        totalChunks: _currentProgress?.totalChunks ?? 0,
        completedChunks: _currentProgress?.completedChunks ?? 0,
        failedChunks: 1,
        status: UploadStatus.failed,
        errorMessage: e.message,
        errorDetail: e.detail,
        failureKind: e.kind,
        canRetry: e.canRetry,
      ));
      rethrow;
    } catch (e, stackTrace) {
      _logError('Unexpected upload error',
          'Unexpected error during upload of track ${track.id}: $e', track.id);
      unawaited(ErrorService.reportToSentry(
          'Unexpected error during batch upload of track ${track.id}: $e',
          stackTrace));

      final errorType = UploadErrorClassifier.classifyError(e);
      final isAuthError = errorType == UploadErrorType.permanentAuth;
      if (isAuthError) {
        await _handleAuthenticationError(e.toString());
      }

      _updateProgress(UploadProgress(
        totalChunks: _currentProgress?.totalChunks ?? 0,
        completedChunks: _currentProgress?.completedChunks ?? 0,
        failedChunks: _currentProgress?.failedChunks ?? 0,
        status: UploadStatus.failed,
        errorMessage: isAuthError
            ? _getAuthenticationErrorMessage(e.toString())
            : uploadFailedTryLaterErrorToken,
        errorDetail: isAuthError ? null : describeUploadError(e),
        failureKind: isAuthError ? null : failureKindOf(e),
        canRetry: !isAuthError,
      ));

      rethrow;
    } finally {
      _isUploading = false;
      if (identical(_cancelSignal, cancelSignal)) {
        _cancelSignal = null;
      }
      _logInfo('Upload session ended',
          'Upload session for track ${track.id} completed', track.id);
    }
  }

  /// Stops the running upload. Remaining chunks are not uploaded and the track
  /// is not marked as uploaded. Does nothing if no upload is running.
  void cancelUpload() {
    final signal = _cancelSignal;
    if (signal == null || signal.isCompleted) return;
    _logInfo('Upload cancel requested', 'Cancelling running upload', null);
    signal.complete();
  }

  /// Completes with [future], or throws [UploadCancelledException] as soon as
  /// [cancelUpload] is called. The underlying work is not aborted, its result
  /// is just ignored.
  Future<T> _untilCancelled<T>(Future<T> future) {
    final signal = _cancelSignal;
    if (signal == null) return future;
    if (signal.isCompleted) {
      // Avoid an unhandled error from the ignored future.
      future.ignore();
      throw const UploadCancelledException();
    }
    return Future.any<T>([
      future,
      signal.future.then<T>((_) => throw const UploadCancelledException()),
    ]);
  }

  /// Throws a [BatchUploadException] describing why chunk [chunkIndex] failed.
  Never _failTrackUpload(
    TrackData track,
    ChunkUploadResult result,
    int chunkIndex,
    int totalChunks,
  ) {
    final error = result.error ?? Exception(result.errorMessage);
    _logError(
        'Chunk upload failed',
        'Chunk $chunkIndex/$totalChunks of track ${track.id} failed, stopping upload: $error',
        track.id);

    if (UploadErrorClassifier.classifyError(error) ==
        UploadErrorType.permanentAuth) {
      // Handled by the generic catch in uploadTrack (marks auth as failed).
      throw Exception(
          'Authentication failed - user needs to re-login: $error');
    }

    throw BatchUploadException(
      uploadFailedTryLaterErrorToken,
      detail: describeUploadError(error),
      kind: failureKindOf(error),
      canRetry: true,
      cause: error,
    );
  }

  /// Turns an upload error into the reason shown to the user: the network
  /// error (shortened) or the HTTP status plus the message returned by the API.
  static String describeUploadError(Object? error) {
    if (error is TimeoutException) {
      final seconds = error.duration?.inSeconds;
      return seconds != null
          ? 'No response within $seconds s'
          : 'No response (timeout)';
    }
    if (error is SocketException) {
      final osMessage = error.osError?.message;
      return _cleanNetworkMessage(osMessage != null && osMessage.isNotEmpty
          ? '${error.message} ($osMessage)'
          : error.message);
    }
    if (error is http.ClientException) {
      return _cleanNetworkMessage(error.message);
    }
    if (error is HttpException) {
      return _cleanNetworkMessage(error.message);
    }
    if (error is HandshakeException) {
      return _cleanNetworkMessage('Secure connection failed: ${error.message}');
    }
    if (error is TooManyRequestsException) {
      return 'HTTP 429: Too many requests';
    }
    if (error is ServerErrorException) {
      return _withApiMessage('HTTP ${error.statusCode}', error.body);
    }
    if (error is OpenSenseMapApiException) {
      return _withApiMessage('HTTP ${error.statusCode}', error.body);
    }
    return error?.toString() ?? '';
  }

  /// Whether [error] means openSenseMap could not be reached, or it answered
  /// with an error response.
  static UploadFailureKind failureKindOf(Object? error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is HttpException ||
        error is HandshakeException ||
        error is http.ClientException) {
      return UploadFailureKind.connection;
    }
    if (error is TooManyRequestsException ||
        error is ServerErrorException ||
        error is OpenSenseMapApiException) {
      return UploadFailureKind.apiResponse;
    }
    return UploadFailureKind.other;
  }

  /// Shortens dart:io error text for display, e.g.
  /// "SocketException: Failed host lookup: 'x' (OS Error: No address
  /// associated with hostname, errno = 7)" becomes
  /// "Failed host lookup: 'x' (No address associated with hostname)".
  static String _cleanNetworkMessage(String message) {
    return message
        .replaceFirst(RegExp(r'^(SocketException|HttpException|HandshakeException):\s*'), '')
        .replaceAll('OS Error: ', '')
        .replaceAll(RegExp(r',\s*errno = \d+'), '')
        .trim();
  }

  static String _withApiMessage(String prefix, String? body) {
    final message = _extractApiMessage(body);
    return message == null ? prefix : '$prefix: $message';
  }

  static String? _extractApiMessage(String? body) {
    final trimmed = body?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        for (final key in const ['message', 'error', 'code']) {
          final value = decoded[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } catch (_) {
      // Not JSON, fall through.
    }
    // HTML error pages (e.g. from a proxy) are not useful to show.
    if (trimmed.startsWith('<')) return null;
    return trimmed.length > 200 ? '${trimmed.substring(0, 200)}…' : trimmed;
  }

  /// Retries upload for tracks that have failed uploads with comprehensive error handling.
  /// 
  /// This method finds all tracks where uploaded is false and attempts to upload them.
  /// It's useful for batch retrying after network connectivity is restored.
  /// Implements automatic retry for temporary errors with exponential backoff.
  /// 
  /// [senseBox] - SenseBox configuration containing sensor mappings
  /// 
  /// Returns the number of tracks successfully uploaded
  Future<int> retryFailedUploads(SenseBox senseBox) async {
    if (_isUploading) {
      const errorMessage = 'Another upload is already in progress';
      _logError('Retry blocked', errorMessage, null);
      throw Exception(errorMessage);
    }

    _logInfo('Retry session start', 'Starting retry session for failed uploads', null);

    // Get all tracks that haven't been uploaded with error handling
    List<TrackData> failedTracks;
    try {
      final allTracks = await _trackService.getAllTracks();
      failedTracks = allTracks.where((track) => track.uploaded != 1).toList();
    } catch (e, stackTrace) {
      _logError('Track loading failed', 'Failed to load tracks for retry: $e', null);
      ErrorService.handleError(
        'Failed to load tracks for retry: $e',
        stackTrace,
        sendToSentry: true,
      );
      throw Exception('Failed to load tracks for retry. Please try again.');
    }
    
    if (failedTracks.isEmpty) {
      _logInfo('No retries needed', 'No failed uploads to retry', null);
      return 0;
    }

    // Sort tracks by last upload attempt (oldest first) to prioritize older failures
    failedTracks.sort((a, b) {
      final aTime = a.lastUploadAttempt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastUploadAttempt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    _logInfo('Retry session info', 'Retrying ${failedTracks.length} failed uploads', null);
    
    int successCount = 0;
    int permanentFailureCount = 0;
    int temporaryFailureCount = 0;
    
    for (int i = 0; i < failedTracks.length; i++) {
      final track = failedTracks[i];
      
      try {
        _logInfo('Track retry start', 'Retrying track ${track.id} (${i + 1}/${failedTracks.length})', track.id);
        await uploadTrack(track, senseBox);
        successCount++;
        _logInfo('Track retry success', 'Successfully retried track ${track.id}', track.id);
        
      } catch (e, stackTrace) {
        _logError('Track retry failed', 'Failed to retry upload for track ${track.id}: $e', track.id);
        
        // Classify the error to determine how to handle it
        final errorType = UploadErrorClassifier.classifyError(e);
        
        // If authentication failed, stop retrying other tracks
        if (errorType == UploadErrorType.permanentAuth) {
          await _handleAuthenticationError(e.toString());
          _logError('Retry session stopped',
              'Stopping retry due to authentication failure', null);
          break;
        }
        
        // Report error for monitoring
        ErrorService.handleError(
          'Failed to retry upload for track ${track.id}: $e',
          stackTrace,
          sendToSentry: errorType != UploadErrorType.temporary,
        );
        
        // Count failure types for reporting
        if (errorType == UploadErrorType.temporary) {
          temporaryFailureCount++;
        } else {
          permanentFailureCount++;
        }
      }
    }
    
    _logInfo('Retry session complete', 
      'Retry session completed: $successCount successful, $temporaryFailureCount temporary failures, $permanentFailureCount permanent failures', 
      null);
    
    return successCount;
  }


  /// Handles authentication errors by marking authentication as failed in OpenSenseMapBloc
  /// This preserves track data locally and allows the user to re-authenticate
  Future<void> _handleAuthenticationError(String errorMessage) async {
    debugPrint('[BatchUploadService] Handling authentication error: $errorMessage');
    
    try {
      // Mark authentication as failed in the bloc
      // This will clear authentication state and notify listeners
      await _openSenseMapBloc.markAuthenticationFailed();
      
      debugPrint('[BatchUploadService] Authentication marked as failed, user needs to re-login');
    } catch (e) {
      debugPrint('[BatchUploadService] Error while marking authentication as failed: $e');
    }
  }

  /// Generates a user-friendly error message for authentication failures
  String _getAuthenticationErrorMessage(String originalError) {
    // Return a consistent, user-friendly message for authentication errors
    return 'Authentication failed. Please log in again to upload your tracks.';
  }

  /// Updates the current progress and emits it to the stream
  void _updateProgress(UploadProgress progress) {
    _currentProgress = progress;
    // The owner may dispose the service while an upload is still finishing
    // (e.g. the modal was closed); drop late updates instead of throwing.
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  /// Logs informational messages with structured format
  void _logInfo(String operation, String message, int? trackId) {
    final timestamp = DateTime.now().toIso8601String();
    final trackInfo = trackId != null ? ' [Track: $trackId]' : '';
    debugPrint('[$timestamp] [BatchUploadService] [INFO] [$operation]$trackInfo $message');
  }

  /// Logs error messages with structured format
  void _logError(String operation, String message, int? trackId) {
    final timestamp = DateTime.now().toIso8601String();
    final trackInfo = trackId != null ? ' [Track: $trackId]' : '';
    debugPrint('[$timestamp] [BatchUploadService] [ERROR] [$operation]$trackInfo $message');
  }

  /// Disposes of the service and closes the progress stream
  void dispose() {
    _logInfo('Service disposal', 'BatchUploadService disposed', null);
    cancelUpload();
    _progressController.close();
  }
}

/// Thrown by [BatchUploadService.uploadTrack] when a chunk could not be
/// uploaded. [message] and [detail] are what the progress modal shows.
class BatchUploadException implements Exception {
  final String message;
  final String? detail;
  final UploadFailureKind? kind;
  final bool canRetry;
  final Object? cause;

  const BatchUploadException(
    this.message, {
    this.detail,
    this.kind,
    this.canRetry = true,
    this.cause,
  });

  @override
  String toString() =>
      'BatchUploadException: ${detail ?? message}${cause != null ? ' ($cause)' : ''}';
}

/// Internal signal that the user cancelled the running upload.
class UploadCancelledException implements Exception {
  const UploadCancelledException();

  @override
  String toString() => 'Upload cancelled by user';
}
