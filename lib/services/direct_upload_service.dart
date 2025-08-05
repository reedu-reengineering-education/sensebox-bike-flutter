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
    if (_isPermanentlyDisabled || !_isEnabled) {
      return false;
    }

    for (final entry in groupedData.entries) {
      final GeolocationData geolocation = entry.key;
      final Map<String, List<double>> sensorData = entry.value;

      _accumulatedSensorData.putIfAbsent(geolocation, () => {});
      _accumulatedSensorData[geolocation]!.addAll(sensorData);
    }

    final bool shouldUpload = _accumulatedSensorData.length >= 3;

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
    _directUploadBuffer.add(uploadData);

    // Clear accumulated sensor data after preparing upload data
    // This prevents duplicate data from being uploaded in subsequent batches
    _accumulatedSensorData.clear();


    if (_directUploadBuffer.length >= 3) {
      _uploadDirectBuffer().then((_) {
        _onUploadSuccess?.call(gpsPointsBeingUploaded);
      }).catchError((e) {
      });
    }
  }

  void _prepareAndUploadDataSync(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) {
      return;
    }

    final uploadData = _dataPreparer.prepareDataFromGroupedData(
        _accumulatedSensorData, gpsBuffer);
    _directUploadBuffer.add(uploadData);
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
      } catch (e, st) {
        ErrorService.handleError(
            'Direct upload failed during recording stop at ${DateTime.now()}: $e. Data preserved for next session.',
            st,
            sendToSentry: true);
        
      }
    }
    
    _accumulatedSensorData.clear();
    _directUploadBuffer.clear();
  }

  Future<void> _uploadDirectBuffer() async {
    if (_directUploadBuffer.isEmpty) {
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
      for (final preparedData in _directUploadBuffer) {
        data.addAll(preparedData);
      }

      if (data.isEmpty) {
        return;
      }

      await _uploadDirectBufferWithRetry(data);
      
      // Only clear upload buffer after successful upload (accumulated data already cleared in _prepareAndUploadData)
      _directUploadBuffer.clear();
      
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

    await openSenseMapService.uploadData(senseBox.id, data);
  }

  /// Clears all buffers
  void _clearAllBuffers() {
    _accumulatedSensorData.clear();
    _directUploadBuffer.clear();
  }

  void _clearAllBuffersForNewRecording() {
    _clearAllBuffers();
    _consecutiveFails = 0;
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
    if (_restartAttempts >= maxRestartAttempts) {
      return;
    }

    _restartAttempts++;
    final delayMinutes = baseRestartDelayMinutes *
        _restartAttempts; // Exponential backoff: 2, 4, 6, 8, 10 minutes

    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(minutes: delayMinutes), () {
      _attemptRestart();
    });
  }

  void _resetRestartAttempts() {
    _restartAttempts = 0;
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  void _startUploadTimer() {
    _uploadTimer = Timer.periodic(Duration(seconds: 15), (_) {
      if (_accumulatedSensorData.isNotEmpty) {
        final gpsBuffer = _accumulatedSensorData.keys.toList();

        _prepareAndUploadData(gpsBuffer);
      } 
    });
  }
  Future<void> _handleUploadError(dynamic e, StackTrace st) async {
    if (_isAuthenticationError(e)) {
      await _handleAuthenticationError(e, st);
    } else {
      _handleNonAuthenticationError(e, st);
    }
  }

  bool _isAuthenticationError(dynamic e) {
    final errorString = e.toString();
    
    // Permanent authentication failures that should disable the service
    if (errorString
            .contains('Authentication failed - user needs to re-login') ||
        errorString.contains('No refresh token found') ||
        errorString.contains('Failed to refresh token:')) {
      return true;
    }

    // Temporary authentication errors that should be handled by OpenSenseMap service
    if (errorString.contains('Not authenticated') ||
        errorString.contains('Token refreshed, retrying')) {
      return false; // Let OpenSenseMap service handle these
    }

    return false;
  }

  Future<void> _handleAuthenticationError(dynamic e, StackTrace st) async {
    final errorString = e.toString();
    
    if (errorString
            .contains('Authentication failed - user needs to re-login') ||
        errorString.contains('No refresh token found') ||
        errorString.contains('Failed to refresh token:')) {
      // Permanent authentication failure - disable service permanently
      ErrorService.handleError(
          'Direct upload permanent authentication failure at ${DateTime.now()}: $e. Service disabled.',
          st,
          sendToSentry: true);
      
      _disableAndClearBuffers();
    } else {
      // This shouldn't happen with current logic, but keeping for safety
      ErrorService.handleError(
          'Direct upload authentication error at ${DateTime.now()}: $e. Will retry after token refresh.',
          st,
          sendToSentry: false);
      
      // Add a delay to allow token refresh to complete
      await Future.delayed(Duration(seconds: 5));
    }
  }

  void _handleNonAuthenticationError(dynamic e, StackTrace st) {
    final errorString = e.toString();
    
    // Don't count temporary authentication errors as failures
    // These should be handled by OpenSenseMap service's retry mechanism
    if (errorString.contains('Not authenticated') ||
        errorString.contains('Token refreshed, retrying')) {
      ErrorService.handleError(
          'Direct upload temporary authentication error at ${DateTime.now()}: $e. OpenSenseMap service will handle retry.',
          st,
          sendToSentry: false);
      return; // Don't count as failure, don't disable service
    }
    
    // Don't count temporary server errors (5xx) as permanent failures
    // These should be retried by the OpenSenseMap service
    if (errorString.contains('Server error 502') ||
        errorString.contains('Server error 503') ||
        errorString.contains('Server error 504') ||
        errorString.contains('Server error 500')) {
      ErrorService.handleError(
          'Direct upload temporary server error at ${DateTime.now()}: $e. OpenSenseMap service will handle retry.',
          st,
          sendToSentry: false);
      return; // Don't count as failure, don't disable service
    }

    // Don't count rate limiting errors as permanent failures
    if (errorString.contains('TooManyRequestsException') ||
        errorString.contains('429')) {
      ErrorService.handleError(
          'Direct upload rate limited at ${DateTime.now()}: $e. OpenSenseMap service will handle retry.',
          st,
          sendToSentry: false);
      return; // Don't count as failure, don't disable service
    }

    // Handle other errors (likely 4xx client errors) as potential permanent failures
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
      disableTemporarily();
    }
  }

  void _handlePermanentFailure(
      StackTrace st, bool isPermanentConnectivityIssue) {
    final message = isPermanentConnectivityIssue
        ? 'Permanent connectivity failure: No connection for more than $premanentConnectivityFalurePeriod minutes.'
        : 'Permanent connectivity failure: Max retries ($maxRetries) exceeded.';
    ErrorService.handleError(message, st, sendToSentry: true);
    _disableAndClearBuffers();
    _scheduleRestart();

    ErrorService.handleError(UploadFailureError(), st, sendToSentry: true);
  }

  void _attemptRestart() {
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
  }

  Future<void> _uploadDirectBufferSync() async {
    if (_directUploadBuffer.isEmpty) return;

    // Prevent concurrent uploads
    if (_isDirectUploading) return;
    _isDirectUploading = true;

    try {
      final Map<String, dynamic> data = {};
      for (final preparedData in _directUploadBuffer) {
        data.addAll(preparedData);
      }

      if (data.isEmpty) return;

      await _uploadDirectBufferWithRetry(data);

      // Only clear upload buffer after successful upload (accumulated data already cleared in _prepareAndUploadDataSync)
      _directUploadBuffer.clear();

      // Track successful upload
      _lastSuccessfulUpload = DateTime.now();
      _consecutiveFails = 0;
    } catch (e, st) {
      await _handleUploadError(e, st);
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
  bool _isDirectUploading = false;
} 