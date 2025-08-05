import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import "package:sensebox_bike/constants.dart";

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
  DateTime? _lastSuccessfulUpload;
  int _consecutiveFails = 0;
  
  // Automatic restart mechanism
  Timer? _restartTimer;
  int _restartAttempts = 0;
  static const int maxRestartAttempts = 5;
  static const int baseRestartDelayMinutes = 2;
  


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
    _isEnabled = true;
    _isPermanentlyDisabled = false;
    
    // Reset restart attempts when manually enabling
    _resetRestartAttempts();
    
    // Clear all buffers when starting a new recording to prevent uploading data from previous tracks
    _clearAllBuffersForNewRecording();
    
    // Start upload timer
    _startUploadTimer();
  }

  void disable() {
    _isEnabled = false;
    _isPermanentlyDisabled = true;
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  void disableTemporarily() {
    _isEnabled = false;
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  bool get isEnabled => _isEnabled;
  bool get hasPreservedData => _accumulatedSensorData.isNotEmpty;

  void setUploadSuccessCallback(Function(List<GeolocationData>) callback) {
    _onUploadSuccess = callback;
  }

  bool addGroupedDataForUpload(
      Map<GeolocationData, Map<String, List<double>>> groupedData,
      List<GeolocationData> gpsBuffer) {
    // Don't accept data if service is permanently disabled
    if (_isPermanentlyDisabled) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Service permanently disabled, rejecting data');
      return false;
    }

    // Don't accept data if service is temporarily disabled
    if (!_isEnabled) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Service temporarily disabled, rejecting data');
      return false;
    }

    // Accumulate sensor data from all sensors
    for (final entry in groupedData.entries) {
      final GeolocationData geolocation = entry.key;
      final Map<String, List<double>> sensorData = entry.value;

      // Initialize geolocation entry if not exists
      _accumulatedSensorData.putIfAbsent(geolocation, () => {});

      // Add all sensor data for this geolocation
      _accumulatedSensorData[geolocation]!.addAll(sensorData);
    }

    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Received ${groupedData.length} GPS points, accumulated: ${_accumulatedSensorData.length}');

    // Log each GPS point received for debugging
    for (final entry in groupedData.entries) {
      final GeolocationData geolocation = entry.key;
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: GPS point received - lat: ${geolocation.latitude}, lng: ${geolocation.longitude}, timestamp: ${geolocation.timestamp}');
    }

    // Check if we have enough data to upload (threshold-based)
    // Upload immediately if we have 3+ GPS points
    final bool shouldUpload = _accumulatedSensorData.length >= 3;

    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Upload threshold check - accumulated: ${_accumulatedSensorData.length}, shouldUpload: $shouldUpload');

    if (shouldUpload) {
      _prepareAndUploadData(gpsBuffer);
    }
    
    return true; // Data was successfully added to buffer
  }

  void _prepareAndUploadData(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: No accumulated sensor data to prepare for upload');
      return;
    }

    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Preparing upload for ${_accumulatedSensorData.length} GPS points, buffer size: ${_directUploadBuffer.length}');

    // Store the GPS points that are being uploaded
    final List<GeolocationData> gpsPointsBeingUploaded =
        _accumulatedSensorData.keys.toList();


    
    // Prepare upload data from accumulated sensor data
    final uploadData = _dataPreparer.prepareDataFromGroupedData(
        _accumulatedSensorData, gpsBuffer);
    _directUploadBuffer.add(uploadData);
    
    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Added prepared data to buffer, new buffer size: ${_directUploadBuffer.length}');

    // Upload if buffer is ready (reduced threshold from 10 to 3 for more frequent uploads)
    if (_directUploadBuffer.length >= 3) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Buffer threshold met (${_directUploadBuffer.length} >= 3), triggering upload');
      _uploadDirectBuffer().then((_) {
        // Notify success callback with the GPS points that were uploaded
        _onUploadSuccess?.call(gpsPointsBeingUploaded);
      }).catchError((e) {
        // Upload failed, don't notify success callback
        // Data will be retried on next flush
        debugPrint(
            '[${DateTime.now().toString()}] Direct upload: Upload failed, will retry on next flush');
      });
    } else {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Buffer threshold not met (${_directUploadBuffer.length} < 3), waiting for more data');
    }
  }

  void _prepareAndUploadDataSync(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) {
      return;
    }

    // Store the GPS points that are being uploaded
    final List<GeolocationData> gpsPointsBeingUploaded =
        _accumulatedSensorData.keys.toList();

    // Prepare upload data from accumulated sensor data
    final uploadData = _dataPreparer.prepareDataFromGroupedData(
        _accumulatedSensorData, gpsBuffer);
    _directUploadBuffer.add(uploadData);
  }

  Future<void> uploadRemainingBufferedData() async {
    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Starting uploadRemainingBufferedData');
    
    // Force upload of any remaining accumulated sensor data
    if (_accumulatedSensorData.isNotEmpty) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Found ${_accumulatedSensorData.length} GPS points to upload');
      // Use the GPS points from _accumulatedSensorData instead of empty list
      final gpsBuffer = _accumulatedSensorData.keys.toList();
      _prepareAndUploadDataSync(gpsBuffer);
    } else {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: No accumulated sensor data to upload');
    }

    // Force upload even if buffer threshold is not met (for testing and final flush)
    if (_directUploadBuffer.isNotEmpty) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Found ${_directUploadBuffer.length} prepared buffers to upload');
      try {
        await _uploadDirectBufferSync();
        debugPrint(
            '[${DateTime.now().toString()}] Direct upload: Successfully uploaded remaining buffered data');
      } catch (e, st) {
        ErrorService.handleError(
            'Direct upload failed during recording stop at ${DateTime.now()}: $e. Data preserved for next session.',
            st,
            sendToSentry: true);
        
        // Don't re-throw - we're clearing buffers anyway, so just log the error
      }
    } else {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: No prepared buffers to upload');
    }
    
    // Always clear buffers regardless of upload success/failure
    _accumulatedSensorData.clear();
    _directUploadBuffer.clear();

    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Completed uploadRemainingBufferedData');
  }

  Future<void> _uploadDirectBuffer() async {
    if (_directUploadBuffer.isEmpty) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: No prepared buffers to upload');
      return;
    }

    // Prevent concurrent uploads
    if (_isDirectUploading) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Upload already in progress, skipping');
      return;
    }
    _isDirectUploading = true;

    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Starting upload of ${_directUploadBuffer.length} buffers');

    try {
      // Merge all prepared data maps into one
      final Map<String, dynamic> data = {};
      for (final preparedData in _directUploadBuffer) {
        data.addAll(preparedData);
      }

      if (data.isEmpty) {
        debugPrint(
            '[${DateTime.now().toString()}] Direct upload: Merged data is empty, skipping upload');
        return;
      }

      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Merged ${_directUploadBuffer.length} buffers into single upload data');
      await _uploadDirectBufferWithRetry(data);
      
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Successfully uploaded ${_directUploadBuffer.length} buffers');
      
      // Only clear buffers after successful upload
      _directUploadBuffer.clear();
      _accumulatedSensorData.clear();
      
      // Track successful upload
      _lastSuccessfulUpload = DateTime.now();
      _consecutiveFails = 0;
    } catch (e, st) {
      await _handleUploadError(e, st);
    } finally {
      _isDirectUploading = false;
    }
  }

  Future<void> _uploadDirectBufferWithRetry(Map<String, dynamic> data) async {
    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Calling OpenSenseMapService.uploadData with ${data.length} data entries');

    // Let OpenSenseMapService handle token refresh automatically
    // It will refresh tokens on 401 errors and retry the request
    await openSenseMapService.uploadData(senseBox.id, data);

    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: OpenSenseMapService.uploadData completed successfully');
  }

  /// Flushes all buffers to prevent data accumulation after max retries

  /// Clears all buffers
  void _clearAllBuffers() {
    _accumulatedSensorData.clear();
    _directUploadBuffer.clear();
  }

  /// Clears all buffers when starting a new recording to prevent uploading data from previous tracks
  void _clearAllBuffersForNewRecording() {
    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Clearing all buffers for new recording');
    _clearAllBuffers();
    _consecutiveFails = 0;
  }

  /// Disables the service and clears all buffers to prevent data accumulation
  void _disableAndClearBuffers() {
    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Disabling service and clearing buffers due to permanent failure');
    _isEnabled = false;
    _isPermanentlyDisabled = true;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _clearAllBuffers();
    permanentUploadLossNotifier.value = true;
  }

  /// Schedules automatic restart with exponential backoff
  void _scheduleRestart() {
    if (_restartAttempts >= maxRestartAttempts) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Max restart attempts ($maxRestartAttempts) reached, not scheduling restart');
      return;
    }

    _restartAttempts++;
    final delayMinutes = baseRestartDelayMinutes *
        _restartAttempts; // Exponential backoff: 2, 4, 6, 8, 10 minutes

    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Scheduling restart attempt $_restartAttempts in $delayMinutes minutes');

    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(minutes: delayMinutes), () {
      _attemptRestart();
    });
  }

  /// Resets restart attempts counter and cancels restart timer
  void _resetRestartAttempts() {
    _restartAttempts = 0;
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  /// Starts the upload timer
  void _startUploadTimer() {
    _uploadTimer = Timer.periodic(Duration(seconds: 15), (_) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Timer fired, accumulated data: ${_accumulatedSensorData.length}');
      if (_accumulatedSensorData.isNotEmpty) {
        // Use actual GPS data from accumulated sensor data instead of empty buffer
        final gpsBuffer = _accumulatedSensorData.keys.toList();
        debugPrint(
            '[${DateTime.now().toString()}] Direct upload: Timer triggered upload with ${gpsBuffer.length} GPS points');
        _prepareAndUploadData(gpsBuffer);
      } else {
        debugPrint(
            '[${DateTime.now().toString()}] Direct upload: Timer fired but no accumulated data to upload');
      }
    });
  }

  /// Handles upload errors with proper categorization and response
  Future<void> _handleUploadError(dynamic e, StackTrace st) async {
    if (_isAuthenticationError(e)) {
      await _handleAuthenticationError(e, st);
    } else {
      _handleNonAuthenticationError(e, st);
    }
  }

  /// Checks if the error is an authentication error
  bool _isAuthenticationError(dynamic e) {
    return e.toString().contains('Not authenticated') ||
        e.toString().contains('401 Unauthorized') ||
        e.toString().contains('Authentication failed');
  }

  /// Handles authentication errors with delay for token refresh
  Future<void> _handleAuthenticationError(dynamic e, StackTrace st) async {
    ErrorService.handleError(
        'Direct upload authentication error at ${DateTime.now()}: $e. Will retry after token refresh.',
        st,
        sendToSentry: false);
    
    // Add a delay to allow token refresh to complete
    await Future.delayed(Duration(seconds: 5));

    // Don't treat authentication errors as permanent failures
    // Let the finally block reset _isDirectUploading and retry later
  }

  /// Handles non-authentication errors with failure tracking
  void _handleNonAuthenticationError(dynamic e, StackTrace st) {
    ErrorService.handleError(
        'Direct upload API error at ${DateTime.now()}: $e. Data buffers preserved for retry.',
        st,
        sendToSentry: true);

    _consecutiveFails++;

    final lastSuccessfulUploadPeriod = DateTime.now()
        .subtract(Duration(minutes: premanentConnectivityFalurePeriod));
    final isPermanentConnectivityIssue = _lastSuccessfulUpload != null &&
        _lastSuccessfulUpload!.isBefore(lastSuccessfulUploadPeriod);
    final isMaxRetries = _consecutiveFails >= maxRetries;

    if (isPermanentConnectivityIssue || isMaxRetries) {
      _handlePermanentFailure(st, isPermanentConnectivityIssue);
    } else {
      // For temporary errors, just disable temporarily
      disableTemporarily();
    }
  }

  /// Handles permanent failure by disabling service and scheduling restart
  void _handlePermanentFailure(
      StackTrace st, bool isPermanentConnectivityIssue) {
    final message = isPermanentConnectivityIssue
        ? 'Permanent connectivity failure: No connection for more than $premanentConnectivityFalurePeriod minutes.'
        : 'Permanent connectivity failure: Max retries ($maxRetries) exceeded.';
    ErrorService.handleError(message, st, sendToSentry: true);

    // Permanently disable for connectivity issues and clear buffers
    _disableAndClearBuffers();

    // Schedule automatic restart
    _scheduleRestart();

    ErrorService.handleError(UploadFailureError(), st, sendToSentry: true);
  }

  /// Attempts to restart the service
  void _attemptRestart() {
    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Attempting restart (attempt $_restartAttempts)');

    // Clear all buffers for fresh start after restart
    _clearAllBuffers();

    // Reset failure counters
    _consecutiveFails = 0;
    _lastSuccessfulUpload = null;

    // Re-enable the service
    _isEnabled = true;
    _isPermanentlyDisabled = false;
    permanentUploadLossNotifier.value = false;

    // Restart the upload timer
    _startUploadTimer();

    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Service restarted successfully with cleared buffers');
  }

  Future<void> _uploadDirectBufferSync() async {
    if (_directUploadBuffer.isEmpty) return;

    // Prevent concurrent uploads
    if (_isDirectUploading) return;
    _isDirectUploading = true;

    try {
      // Merge all prepared data maps into one
      final Map<String, dynamic> data = {};
      for (final preparedData in _directUploadBuffer) {
        data.addAll(preparedData);
      }

      if (data.isEmpty) return;

      await _uploadDirectBufferWithRetry(data);

      // Only clear buffers after successful upload
      _directUploadBuffer.clear();
      _accumulatedSensorData.clear();

      // Track successful upload
      _lastSuccessfulUpload = DateTime.now();
      _consecutiveFails = 0;
    } catch (e, st) {
      await _handleUploadError(e, st);

      // Re-throw the exception so the caller knows the upload failed
      rethrow;
    } finally {
      _isDirectUploading = false;
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
    permanentUploadLossNotifier.dispose();
  }

  // Internal flag to prevent concurrent uploads
  bool _isDirectUploading = false;
} 