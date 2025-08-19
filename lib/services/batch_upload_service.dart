import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/chunked_uploader.dart';
import 'package:sensebox_bike/services/upload_retry_manager.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';

/// Service responsible for coordinating batch uploads of complete tracks.
/// 
/// This service handles the complete upload flow:
/// 1. Splits tracks into chunks using ChunkedUploader
/// 2. Uploads chunks with retry logic using UploadRetryManager
/// 3. Provides real-time progress updates via stream
/// 4. Updates track status when upload completes
/// 5. Handles authentication failures and other errors
class BatchUploadService {
  final OpenSenseMapService _openSenseMapService;
  final TrackService _trackService;
  final UploadRetryManager _retryManager;
  final OpenSenseMapBloc _openSenseMapBloc;
  
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
    UploadRetryManager? retryManager,
  }) : _openSenseMapService = openSenseMapService,
       _trackService = trackService,
       _openSenseMapBloc = openSenseMapBloc,
       _retryManager = retryManager ?? UploadRetryManager.forNetworkOperations();

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

  /// Uploads a complete track by splitting it into chunks and uploading them sequentially.
  /// 
  /// This method handles the complete upload flow:
  /// 1. Validates track and authentication
  /// 2. Splits track into chunks using ChunkedUploader
  /// 3. Uploads each chunk with retry logic
  /// 4. Updates track status on success
  /// 5. Provides progress updates throughout the process
  /// 6. Preserves data locally on failures for manual retry
  /// 7. Implements comprehensive error handling and logging
  /// 
  /// [track] - The TrackData to upload
  /// [senseBox] - SenseBox configuration containing sensor mappings
  /// 
  /// Throws [Exception] if upload fails permanently or authentication fails
  Future<void> uploadTrack(TrackData track, SenseBox senseBox) async {
    if (_isUploading) {
      const errorMessage = 'Another upload is already in progress';
      _logError('Upload attempt blocked', errorMessage, track.id);
      throw Exception(errorMessage);
    }

    _isUploading = true;
    _logInfo('Starting upload', 'Track ${track.id} upload initiated', track.id);
    
    try {
      // Update track upload attempt tracking with data preservation
      track.uploadAttempts++;
      track.lastUploadAttempt = DateTime.now();
      await _trackService.saveTrack(track);
      _logInfo('Upload attempt tracked', 'Attempt ${track.uploadAttempts} for track ${track.id}', track.id);

      // Emit preparing status
      _updateProgress(UploadProgress(
        totalChunks: 0,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.preparing,
        canRetry: false,
      ));

      // Wait for authentication validation to complete before checking authentication
      await _waitForAuthenticationValidation();

      // Check authentication before starting upload
      if (!_openSenseMapBloc.isAuthenticated) {
        const errorMessage = 'Authentication failed - user needs to re-login';
        _logError('Authentication check failed', errorMessage, track.id);
        await _handleAuthenticationError(errorMessage);
        throw Exception(_getAuthenticationErrorMessage(errorMessage));
      }

      // Create chunked uploader for this track
      final chunkedUploader = ChunkedUploader(
        openSenseMapService: _openSenseMapService,
        senseBox: senseBox,
      );

      // Load track data and split into chunks with error handling
      try {
        await track.geolocations.load();
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
        _logInfo('Empty track', 'No geolocation data found for track ${track.id}', track.id);
        _updateProgress(UploadProgress(
          totalChunks: 0,
          completedChunks: 0,
          failedChunks: 0,
          status: UploadStatus.completed,
          canRetry: false,
        ));
        return;
      }

      // Sort geolocations by timestamp to ensure chronological order
      geolocations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Split into chunks with error handling based on measurement estimation
      final chunks = chunkedUploader.splitIntoChunks(geolocations, senseBox);
      final totalChunks = chunks.length;

      _logInfo('Upload preparation complete', 
        'Track ${track.id} split into $totalChunks chunks (${geolocations.length} total points)', 
        track.id);

      // Emit uploading status with total chunks
      _updateProgress(UploadProgress(
        totalChunks: totalChunks,
        completedChunks: 0,
        failedChunks: 0,
        status: UploadStatus.uploading,
        canRetry: false,
      ));

      // Upload each chunk with comprehensive error handling and retry logic
      int completedChunks = 0;
      int failedChunks = 0;
      String? lastError;
      bool canRetry = true;
      final List<int> failedChunkIndices = [];

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        
        try {
          _logInfo('Chunk upload start', 'Starting upload of chunk $i/${chunks.length} for track ${track.id}', track.id);
          
          // Upload chunk with retry logic and comprehensive error handling
          await _retryManager.executeWithRetry(
            () async {
              final result = await chunkedUploader.uploadChunk(chunk, senseBox, i);
              if (result.failed) {
                final errorMessage = result.errorMessage ?? 'Chunk upload failed';
                _logError('Chunk upload failed', 'Chunk $i failed: $errorMessage', track.id);
                throw Exception(errorMessage);
              }
              return result;
            },
            onRetry: (exception, attempt) {
              _logInfo('Chunk retry', 'Retrying chunk $i upload, attempt $attempt: $exception', track.id);
              
              // Emit retrying status with detailed information
              _updateProgress(UploadProgress(
                totalChunks: totalChunks,
                completedChunks: completedChunks,
                failedChunks: failedChunks,
                status: UploadStatus.retrying,
                errorMessage: 'Retrying chunk $i (attempt $attempt): ${exception.toString()}',
                canRetry: true,
              ));
            },
          );

          // Chunk uploaded successfully
          completedChunks++;
          _logInfo('Chunk upload success', 'Successfully uploaded chunk $i of track ${track.id}', track.id);
          
          // Emit progress update
          _updateProgress(UploadProgress(
            totalChunks: totalChunks,
            completedChunks: completedChunks,
            failedChunks: failedChunks,
            status: UploadStatus.uploading,
            canRetry: false,
          ));

        } catch (e, stackTrace) {
          failedChunks++;
          failedChunkIndices.add(i);
          lastError = e.toString();
          
          // Classify the error to determine how to handle it
          final errorType = UploadErrorClassifier.classifyError(e as Exception);
          
          // Log the error with appropriate severity
          _logError('Chunk upload failed permanently', 
            'Chunk $i of track ${track.id} failed after retries: $e', 
            track.id);
          
          // Report to error service for monitoring
          ErrorService.handleError(
            'Chunk upload failed for track ${track.id}, chunk $i: $e',
            stackTrace,
            sendToSentry: errorType != UploadErrorType.temporary,
          );
          
          // Handle authentication errors
          if (errorType == UploadErrorType.permanentAuth) {
            canRetry = false;
            await _handleAuthenticationError(lastError);
            lastError = _getAuthenticationErrorMessage(lastError);
            _logError('Authentication failure', 'Authentication failed during upload of track ${track.id}', track.id);
            break;
          }

          // Check if this is a permanent client error
          if (errorType == UploadErrorType.permanentClient) {
            canRetry = false;
            _logError('Permanent client error', 'Permanent error during upload of track ${track.id}: $e', track.id);
            break;
          }

          // For temporary errors, continue with next chunk but preserve data
          _logInfo('Temporary error handled', 'Temporary error for chunk $i, continuing with next chunk', track.id);
        }
      }

      // Log final upload statistics
      _logInfo('Upload completed', 
        'Track ${track.id} upload finished: $completedChunks successful, $failedChunks failed chunks. Failed indices: $failedChunkIndices', 
        track.id);

      // Determine final status with comprehensive data preservation
      if (failedChunks == 0) {
        // All chunks uploaded successfully - mark track as uploaded
        track.uploaded = true;
        await _trackService.saveTrack(track);
        
        _updateProgress(UploadProgress(
          totalChunks: totalChunks,
          completedChunks: completedChunks,
          failedChunks: failedChunks,
          status: UploadStatus.completed,
          canRetry: false,
        ));

        _logInfo('Upload success', 'Successfully uploaded track ${track.id} with all $totalChunks chunks', track.id);
        
      } else {
        // Some chunks failed - preserve data locally and emit failed status
        // Data is automatically preserved since we don't mark track as uploaded
        
        final errorMessage = canRetry 
          ? 'Upload failed for $failedChunks chunks. Data preserved locally for retry.'
          : lastError ?? 'Upload failed permanently for $failedChunks chunks. Data preserved locally.';
        
        _updateProgress(UploadProgress(
          totalChunks: totalChunks,
          completedChunks: completedChunks,
          failedChunks: failedChunks,
          status: UploadStatus.failed,
          errorMessage: errorMessage,
          canRetry: canRetry,
        ));

        _logError('Upload failed', 
          'Failed to upload track ${track.id}: $completedChunks/$totalChunks chunks succeeded. Data preserved locally.', 
          track.id);
        
        // Throw exception to indicate failure, but data is preserved
        throw Exception(errorMessage);
      }

    } catch (e, stackTrace) {
      // Handle any unexpected errors with comprehensive logging and data preservation
      _logError('Unexpected upload error', 'Unexpected error during upload of track ${track.id}: $e', track.id);
      
      // Report to error service for monitoring
      ErrorService.handleError(
        'Unexpected error during batch upload of track ${track.id}: $e',
        stackTrace,
        sendToSentry: true,
      );
      
      // Classify the error to determine how to handle it
      final errorType = UploadErrorClassifier.classifyError(e as Exception);
      bool canRetry = true;
      
      // Handle authentication errors
      if (errorType == UploadErrorType.permanentAuth) {
        canRetry = false;
        await _handleAuthenticationError(e.toString());
      }
      
      // Use user-friendly error message for authentication errors
      String displayErrorMessage = e.toString();
      if (errorType == UploadErrorType.permanentAuth) {
        displayErrorMessage = _getAuthenticationErrorMessage(e.toString());
      } else {
        // Add data preservation message for other errors
        displayErrorMessage = '$displayErrorMessage Data preserved locally for retry.';
      }
      
      _updateProgress(UploadProgress(
        totalChunks: _currentProgress?.totalChunks ?? 0,
        completedChunks: _currentProgress?.completedChunks ?? 0,
        failedChunks: _currentProgress?.failedChunks ?? 0,
        status: UploadStatus.failed,
        errorMessage: displayErrorMessage,
        canRetry: canRetry,
      ));
      
      rethrow;
    } finally {
      _isUploading = false;
      _logInfo('Upload session ended', 'Upload session for track ${track.id} completed', track.id);
    }
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
      failedTracks = allTracks.where((track) => !track.uploaded).toList();
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
        final errorType = UploadErrorClassifier.classifyError(e as Exception);
        
        // Report error for monitoring
        ErrorService.handleError(
          'Failed to retry upload for track ${track.id}: $e',
          stackTrace,
          sendToSentry: errorType != UploadErrorType.temporary,
        );
        
        // If authentication failed, stop retrying other tracks
        if (errorType == UploadErrorType.permanentAuth) {
          await _handleAuthenticationError(e.toString());
          _logError('Retry session stopped', 'Stopping retry due to authentication failure', null);
          break;
        }
        
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
    _progressController.add(progress);
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

  /// Logs retry attempts with structured format
  void _logRetry(String operation, String message, int? trackId, int attempt) {
    final timestamp = DateTime.now().toIso8601String();
    final trackInfo = trackId != null ? ' [Track: $trackId]' : '';
    debugPrint('[$timestamp] [BatchUploadService] [RETRY] [$operation]$trackInfo [Attempt: $attempt] $message');
  }

  /// Disposes of the service and closes the progress stream
  void dispose() {
    _logInfo('Service disposal', 'BatchUploadService disposed', null);
    _progressController.close();
  }
}