import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/utils/track_utils.dart';

class DirectUploadService {
  final String instanceId = DateTime.now().millisecondsSinceEpoch.toString();
  final OpenSenseMapService openSenseMapService;
  final SettingsBloc settingsBloc;
  final SenseBox senseBox;
  final UploadDataPreparer _dataPreparer;
  
  // Callback to notify when upload succeeds
  Function(List<GeolocationData>)? _onUploadSuccess;

  // Notifier for permanent upload loss (similar to BLE connection loss)
  final ValueNotifier<bool> permanentUploadLossNotifier =
      ValueNotifier<bool>(false);

  // vars to handle connectivity issues (same as LiveUploadService)
  // Remove _consecutiveFails since we no longer track consecutive failures
  
  // Automatic restart mechanism - simplified since we only restart on permanent failures
  Timer? _restartTimer;
  int _restartAttempts = 0;
  static const int maxRestartAttempts =
      3; // Reduced since we only restart on permanent failures
  static const int baseRestartDelayMinutes =
      5; // Increased delay since these are permanent failures
  


  // Buffer for direct uploads - stores prepared data maps
  final List<Map<String, dynamic>> _directUploadBuffer = [];
  // Buffer for accumulating sensor data before preparing upload
  final Map<GeolocationData, Map<String, List<double>>> _accumulatedSensorData =
      {};
  bool _isEnabled = false;
  bool _isPermanentlyDisabled = false;
  Timer? _uploadTimer;

  DirectUploadService({
    required this.openSenseMapService,
    required this.settingsBloc,
    required this.senseBox,
  }) : _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  void enable() {
    // Check if there are pending restart timers and cancel them
    if (_restartTimer != null) {
      debugPrint(
          '[DirectUploadService] Cancelling pending restart timer during enable');
      _restartTimer?.cancel();
      _restartTimer = null;
    }
    
    _isEnabled = true;
    _isPermanentlyDisabled = false;
    
    // Reset restart attempts when manually enabling
    _resetRestartAttempts();
    
    // Clear all buffers when starting a new recording to prevent uploading data from previous tracks
    _clearAllBuffersForNewRecording();
    
    // Start periodic upload check
    _startPeriodicUploadCheck();

    debugPrint('[DirectUploadService] Service enabled, restart attempts reset');
  }

  void disable() {
    _isEnabled = false;
    _isPermanentlyDisabled = true;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    // Cancel any pending restart timers
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  void disableTemporarily() {
    _isEnabled = false;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    // Cancel any pending restart timers
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  bool get isEnabled => _isEnabled;
  bool get hasPreservedData => _accumulatedSensorData.isNotEmpty;
  
  // Add method to check if there are pending restart timers
  bool get hasPendingRestartTimer => _restartTimer != null;

  void setUploadSuccessCallback(Function(List<GeolocationData>) callback) {
    _onUploadSuccess = callback;
  }

  bool addGroupedDataForUpload(
      Map<GeolocationData, Map<String, List<double>>> groupedData,
      List<GeolocationData> gpsBuffer) {
    // Don't accept data if service is permanently disabled
    if (_isPermanentlyDisabled || !_isEnabled) {
      return false;
    }

    for (final entry in groupedData.entries) {
      final GeolocationData geolocation = entry.key;
      final Map<String, List<double>> sensorData = entry.value;

      _accumulatedSensorData.putIfAbsent(geolocation, () => {});
      _accumulatedSensorData[geolocation]!.addAll(sensorData);
    }

    final bool shouldUpload = _accumulatedSensorData.length >= 6; 

    if (shouldUpload) {
      _prepareAndUploadData(gpsBuffer);
    }
    
    return true; // Data was successfully added to buffer
  }

  void _prepareAndUploadData(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) {
      return;
    }

    // Store the GPS points that are being uploaded
    final List<GeolocationData> gpsPointsBeingUploaded =
        _accumulatedSensorData.keys.toList();

    // Prepare upload data from accumulated sensor data
    final uploadData = _dataPreparer.prepareDataFromGroupedData(
        _accumulatedSensorData, gpsBuffer);
    
    // Store GPS points with the upload data for success callback
    final uploadDataWithGps = {
      'data': uploadData,
      'gpsPoints': gpsPointsBeingUploaded,
    };

    _directUploadBuffer.add(uploadDataWithGps);

    // CRITICAL: Clear accumulated data immediately to prevent memory buildup
    _accumulatedSensorData.clear();

    if (_directUploadBuffer.length >= 3) {
      // Balanced threshold for efficient uploads
      _uploadDirectBuffer().catchError((e) {
        ErrorService.handleError(
            'Direct upload failed at ${DateTime.now()}: ${e.toString()}',
            StackTrace.current,
            sendToSentry: true);
        // Don't clear data on upload failure - it will be retried
      });
    }
  }

  /// Clears only the accumulated data for GPS points that were successfully uploaded
  /// This prevents data loss and ensures data is only cleared after upload confirmation
  void _clearAccumulatedDataForUploadedPoints(
      List<GeolocationData> uploadedPoints) {
    for (final point in uploadedPoints) {
      if (_accumulatedSensorData.containsKey(point)) {
        _accumulatedSensorData.remove(point);
      }
    }
  }

  void _prepareAndUploadDataSync(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) {
      return;
    }

    // Store the GPS points that are being uploaded
    final List<GeolocationData> gpsPointsBeingUploaded =
        _accumulatedSensorData.keys.toList();

    final uploadData = _dataPreparer.prepareDataFromGroupedData(
        _accumulatedSensorData, gpsBuffer);
    
    // Store GPS points with the upload data for success callback
    final uploadDataWithGps = {
      'data': uploadData,
      'gpsPoints': gpsPointsBeingUploaded,
    };

    _directUploadBuffer.add(uploadDataWithGps);
    _accumulatedSensorData.clear();
  }

  Future<void> uploadRemainingBufferedData() async {
    if (_accumulatedSensorData.isNotEmpty) {
      final gpsBuffer = _accumulatedSensorData.keys.toList();
      _prepareAndUploadDataSync(gpsBuffer);
    } 

    if (_directUploadBuffer.isNotEmpty) {
      try {
        await _uploadDirectBufferSync();
        
        // Only clear buffers after successful upload
        _accumulatedSensorData.clear();
        _directUploadBuffer.clear();
        
      } catch (e, st) {
        // Check if it's a non-critical error that should preserve data
        final isNonCriticalError = e is TooManyRequestsException ||
            e.toString().contains('Server error') ||
            e.toString().contains('Token refreshed') ||
            e is TimeoutException;

        if (isNonCriticalError) {
          // Don't clear buffers - data will be retried by periodic timer
          ErrorService.handleError(
              'Direct upload failed during recording stop at ${DateTime.now()}: $e. Data preserved for retry.',
              st,
              sendToSentry: false);
          debugPrint(
              '[DirectUploadService] Non-critical error during recording stop, preserving data for retry');
        } else {
          // For permanent errors, clear buffers to prevent memory leaks
          ErrorService.handleError(
              'Direct upload failed during recording stop at ${DateTime.now()}: $e. Data cleared due to permanent error.',
              st,
              sendToSentry: true);
          _accumulatedSensorData.clear();
          _directUploadBuffer.clear();
        }
      }
    } else {
      // No data to upload, clear accumulated data
      _accumulatedSensorData.clear();
    }
  }

  Future<void> _uploadDirectBuffer() async {
    if (_directUploadBuffer.isEmpty) {
      return;
    }

    // Check if service is rate limited or permanently disabled
    if (!openSenseMapService.isAcceptingRequests) {
      if (openSenseMapService.isPermanentlyDisabled) {
        debugPrint(
            '[DirectUploadService] Service permanently disabled - user needs to re-login');
      } else {
        debugPrint(
            '[DirectUploadService] Rate limited, preserving ${_directUploadBuffer.length} items in buffer');
      }
      return;
    }

    // Prevent concurrent uploads
    if (_isDirectUploading) {
      return;
    }
    _isDirectUploading = true;

    try {
      // Merge all prepared data maps into one
      final Map<String, dynamic> data = {};
      final List<GeolocationData> allGpsPoints = [];

      for (final uploadDataWithGps in _directUploadBuffer) {
        final uploadData = uploadDataWithGps['data'] as Map<String, dynamic>;
        final gpsPoints =
            uploadDataWithGps['gpsPoints'] as List<GeolocationData>;

        data.addAll(uploadData);
        allGpsPoints.addAll(gpsPoints);
      }

      if (data.isEmpty) {
        return;
      }

      // Let OpenSenseMapService handle all retries internally
      await openSenseMapService.uploadData(senseBox.id, data);
      
      // Only clear upload buffer after successful upload
      _directUploadBuffer.clear();
      
      // Call success callback
      _onUploadSuccess?.call(allGpsPoints);
      
      // Track successful upload
      // Remove _consecutiveFails since we no longer track consecutive failures
    } catch (e, st) {
      // Check if it's a non-critical error that should preserve data
      final isNonCriticalError = e is TooManyRequestsException ||
          e.toString().contains('Server error') ||
          e.toString().contains('Token refreshed') ||
          e is TimeoutException;

      if (isNonCriticalError) {
        // Don't clear buffers - data will be retried by OpenSenseMapService
        debugPrint(
            '[DirectUploadService] Non-critical error ($e), preserving data for retry');
        ErrorService.handleError(
            'Direct upload temporary error at ${DateTime.now()}: $e. Data preserved for retry.',
            st,
            sendToSentry: false);
      } else {
        // Handle other errors
        ErrorService.handleError(
            'Direct upload failed at ${DateTime.now()}: ${e.toString()}',
            StackTrace.current,
            sendToSentry: true);
        await _handleUploadError(e, st);
      }
    } finally {
      _isDirectUploading = false;
    }
  }

  void _clearAllBuffers() {
    _accumulatedSensorData.clear();
    _directUploadBuffer.clear();
  }

  void _clearAllBuffersForNewRecording() {
    _clearAllBuffers();
  }

  void _disableAndClearBuffers() {
    _isEnabled = false;
    _isPermanentlyDisabled = true;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _clearAllBuffers();
    permanentUploadLossNotifier.value = true;
  }

  void _scheduleRestart() {
    // Don't schedule restart if service is already enabled
    if (_isEnabled && !_isPermanentlyDisabled) {
      debugPrint(
          '[DirectUploadService] Restart not scheduled - service already enabled');
      return;
    }
    
    if (_restartAttempts >= maxRestartAttempts) {
      debugPrint(
          '[DirectUploadService] Max restart attempts reached (${maxRestartAttempts}), no more restarts scheduled');
      return;
    }

    _restartAttempts++;
    final delayMinutes = baseRestartDelayMinutes *
        _restartAttempts; // Exponential backoff: 5, 10, 15 minutes

    debugPrint(
        '[DirectUploadService] Scheduling restart attempt $_restartAttempts in $delayMinutes minutes');

    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(minutes: delayMinutes), () {
      debugPrint(
          '[DirectUploadService] Executing restart attempt $_restartAttempts after $delayMinutes minutes');
      _attemptRestart();
    });
  }

  void _resetRestartAttempts() {
    _restartAttempts = 0;
    _restartTimer?.cancel();
    _restartTimer = null;
    debugPrint(
        '[DirectUploadService] Restart attempts reset at ${DateTime.now()}');
  }


  Future<void> _handleUploadError(dynamic e, StackTrace st) async {
    final errorString = e.toString();
    
    // Define non-critical (retryable) error patterns
    final isNonCriticalError = e is TooManyRequestsException ||
        errorString.contains('Server error') ||
        errorString.contains('Token refreshed') ||
        e is TimeoutException;
    
    // Define permanent authentication failures
    final isPermanentAuthError = errorString
            .contains('Authentication failed - user needs to re-login') ||
        errorString.contains('No refresh token found') ||
        errorString.contains('Failed to refresh token:');

    // Define permanent client errors (4xx, excluding 429)
    final isPermanentClientError = errorString.contains('Client error') &&
        !errorString
            .contains('429'); // Exclude 429 from permanent client errors

    if (isPermanentAuthError) {
      await _handlePermanentAuthenticationError(e, st);
    } else if (isPermanentClientError) {
      await _handlePermanentClientError(e, st);
    } else if (isNonCriticalError) {
      // For all non-critical errors (429, 5xx, timeouts), preserve data and let OpenSenseMapService handle retries
      ErrorService.handleError(
          'Direct upload temporary error at ${DateTime.now()}: $e. Data preserved for retry.',
          st,
          sendToSentry: false);
      // Don't clear buffers - data will be retried
    } else {
      // Unknown error - log and preserve data
      ErrorService.handleError(
          'Direct upload unknown error at ${DateTime.now()}: $e. Data preserved.',
          st,
          sendToSentry: true);
      // Don't clear buffers - treat as temporary
    }
  }

  Future<void> _handlePermanentAuthenticationError(
      dynamic e, StackTrace st) async {
    ErrorService.handleError(
        'Direct upload permanent authentication failure at ${DateTime.now()}: $e. Service disabled.',
        st,
        sendToSentry: true);
    
    _disableAndClearBuffers();
    _scheduleRestart();
  }

  Future<void> _handlePermanentClientError(dynamic e, StackTrace st) async {
    ErrorService.handleError(
        'Direct upload permanent client error at ${DateTime.now()}: $e. Service disabled.',
        st,
        sendToSentry: true);
    
    _disableAndClearBuffers();
    _scheduleRestart();
  }

  void _attemptRestart() {
    // Check if service is already enabled (prevent race condition)
    if (_isEnabled && !_isPermanentlyDisabled) {
      debugPrint(
          '[DirectUploadService] Restart cancelled - service already enabled');
      return;
    }

    // Try to upload any remaining data before restarting
    if (_directUploadBuffer.isNotEmpty) {
      debugPrint(
          '[DirectUploadService] Attempting to upload remaining data before restart');
      _uploadDirectBuffer().then((_) {
        // Success - data uploaded, now restart
        _clearAllBuffers();
        _isEnabled = true;
        _isPermanentlyDisabled = false;
        permanentUploadLossNotifier.value = false;
        debugPrint(
            '[DirectUploadService] Restart successful after uploading remaining data');
      }).catchError((e) {
        // Failed to upload - preserve data and restart anyway
        debugPrint(
            '[DirectUploadService] Failed to upload remaining data before restart: $e. Data preserved.');
        // Don't clear buffers - preserve data for next attempt
        _isEnabled = true;
        _isPermanentlyDisabled = false;
        permanentUploadLossNotifier.value = false;
      });
    } else {
      // No data to upload, restart immediately
      _clearAllBuffers();
      _isEnabled = true;
      _isPermanentlyDisabled = false;
      permanentUploadLossNotifier.value = false;
      debugPrint(
          '[DirectUploadService] Restart successful (no data to upload)');
    }
  }

  Future<void> _uploadDirectBufferSync() async {
    if (_directUploadBuffer.isEmpty) return;

    // Prevent concurrent uploads
    if (_isDirectUploading) return;
    _isDirectUploading = true;

    try {
      final Map<String, dynamic> data = {};
      for (final uploadDataWithGps in _directUploadBuffer) {
        final uploadData = uploadDataWithGps['data'] as Map<String, dynamic>;
        data.addAll(uploadData);
      }

      if (data.isEmpty) return;

      await openSenseMapService.uploadData(senseBox.id, data);

      _directUploadBuffer.clear();

    } catch (e, st) {
      ErrorService.handleError(
          'Direct upload failed at ${DateTime.now()}: ${e.toString()}',
          StackTrace.current,
          sendToSentry: true);
      await _handleUploadError(e, st);
      rethrow;
    } finally {
      _isDirectUploading = false;
    }
  }

  // Add periodic upload check for rate-limited data
  void _startPeriodicUploadCheck() {
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(Duration(seconds: 30), (_) {
      // Try to upload any buffered data if service is accepting requests
      if (_directUploadBuffer.isNotEmpty &&
          openSenseMapService.isAcceptingRequests) {
        _logBufferStatus();
        _uploadDirectBuffer().catchError((e) {
          debugPrint(
              '[DirectUploadService] Periodic upload attempt failed: $e');
        });
      } else if (_directUploadBuffer.isNotEmpty &&
          openSenseMapService.isPermanentlyDisabled) {
        // Log that uploads are blocked due to authentication failure
        debugPrint(
            '[DirectUploadService] Periodic check: Uploads blocked - user needs to re-login');
      }
    });
  }

  // Add method to log buffer status for debugging
  void _logBufferStatus() {
    debugPrint('[DirectUploadService] Buffer Status:');
    debugPrint(
        '  - Accumulated Sensor Data: ${_accumulatedSensorData.length} GPS points');
    debugPrint('  - Direct Upload Buffer: ${_directUploadBuffer.length} items');
    debugPrint('  - Can Upload: ${openSenseMapService.isAcceptingRequests}');
    debugPrint('  - Service Enabled: $_isEnabled');
    debugPrint('  - Permanently Disabled: $_isPermanentlyDisabled');
    debugPrint('  - Pending Restart Timer: ${_restartTimer != null}');
    debugPrint('  - Restart Attempts: $_restartAttempts');
    debugPrint(
        '  - OpenSenseMap Permanently Disabled: ${openSenseMapService.isPermanentlyDisabled}');

    if (!openSenseMapService.isAcceptingRequests) {
      if (openSenseMapService.isPermanentlyDisabled) {
        debugPrint('  - Status: Permanently disabled - user needs to re-login');
      } else {
        final remaining = openSenseMapService.remainingRateLimitTime;
        debugPrint(
            '  - Rate Limited: ${remaining?.inSeconds ?? 0} seconds remaining');
      }
    }
  }

  void dispose() {
    _isDirectUploading = false;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;
    _directUploadBuffer.clear();
    _accumulatedSensorData.clear();
  }

  bool _isDirectUploading = false;
} 