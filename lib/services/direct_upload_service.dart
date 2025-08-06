import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
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
    _isEnabled = true;
    _isPermanentlyDisabled = false;
    
    // Reset restart attempts when manually enabling
    _resetRestartAttempts();
    
    // Clear all buffers when starting a new recording to prevent uploading data from previous tracks
    _clearAllBuffersForNewRecording();
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
    _directUploadBuffer.add(uploadData);

    // DO NOT clear accumulated sensor data here - wait for successful upload confirmation
    // This prevents data loss when multiple triggers happen in quick succession

    if (_directUploadBuffer.length >= 3) {
      // Balanced threshold for efficient uploads
      _uploadDirectBuffer().then((_) {
        // NOW clear the accumulated data after successful upload confirmation
        _clearAccumulatedDataForUploadedPoints(gpsPointsBeingUploaded);
        
        _onUploadSuccess?.call(gpsPointsBeingUploaded);
      }).catchError((e) {
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

      // Let OpenSenseMapService handle all retries internally
      await openSenseMapService.uploadData(senseBox.id, data);
      
      // Only clear upload buffer after successful upload (accumulated data already cleared in _prepareAndUploadData)
      _directUploadBuffer.clear();
      
      // Track successful upload
      // Remove _consecutiveFails since we no longer track consecutive failures
    } catch (e, st) {
      ErrorService.handleError(
          'Direct upload failed at ${DateTime.now()}: ${e.toString()}',
          StackTrace.current,
          sendToSentry: true);
      await _handleUploadError(e, st);
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
    debugPrint(
        '[DirectUploadService] Restart attempts reset at ${DateTime.now()}');
  }


  Future<void> _handleUploadError(dynamic e, StackTrace st) async {
    final errorString = e.toString();
    ErrorService.handleError(errorString, st, sendToSentry: true);
    
    // Handle permanent authentication failures
    if (errorString
            .contains('Authentication failed - user needs to re-login') ||
        errorString.contains('No refresh token found') ||
        errorString.contains('Failed to refresh token:')) {
      await _handlePermanentAuthenticationError(e, st);
    } else if (errorString.contains('Client error')) {
      // Handle client errors (4xx) as permanent failures
      await _handlePermanentClientError(e, st);
    } else {
      // For all other errors, let OpenSenseMapService handle retries
      // Only log the error but don't take action
      ErrorService.handleError(
          'Direct upload temporary error at ${DateTime.now()}: $e. OpenSenseMap service will handle retry.',
          st,
          sendToSentry: false);
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
    _clearAllBuffers();

    _isEnabled = true;
    _isPermanentlyDisabled = false;
    permanentUploadLossNotifier.value = false;
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