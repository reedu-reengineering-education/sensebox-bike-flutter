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
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';

class UploadErrorClassifier {
  // Error patterns for permanent authentication failures
  static const List<String> _permanentAuthErrorPatterns = [
    'Authentication failed - user needs to re-login',
    'No refresh token found',
    'Failed to refresh token:',
    'Not authenticated',
  ];

  // Error patterns for temporary (retryable) errors
  static const List<String> _temporaryErrorPatterns = [
    'Server error',
    'Token refreshed',
  ];

  // Exception types that are always temporary
  static const List<Type> _temporaryExceptionTypes = [
    TooManyRequestsException,
    TimeoutException,
  ];

  // Exception types that are always permanent authentication errors
  static const List<Type> _permanentAuthExceptionTypes = [
    PermanentAuthenticationError,
  ];

  /// Classifies an error and returns the appropriate error type
  static UploadErrorType classifyError(dynamic error) {
    // Check for permanent authentication exception types first
    if (_isPermanentAuthExceptionType(error)) {
      return UploadErrorType.permanentAuth;
    }

    final errorString = error.toString();

    // Check for permanent authentication errors by string pattern
    if (_isPermanentAuthError(errorString)) {
      return UploadErrorType.permanentAuth;
    }

    // Check for temporary errors
    if (_isTemporaryError(error, errorString)) {
      return UploadErrorType.temporary;
    }

    // Check for permanent client errors (4xx, excluding 429)
    if (_isPermanentClientError(errorString)) {
      return UploadErrorType.permanentClient;
    }

    // Default to temporary for unknown errors
    return UploadErrorType.temporary;
  }

  /// Checks if the error is a permanent authentication error
  static bool _isPermanentAuthError(String errorString) {
    return _permanentAuthErrorPatterns.any(
      (pattern) => errorString.contains(pattern),
    );
  }

  /// Checks if the error is a permanent authentication exception type
  static bool _isPermanentAuthExceptionType(dynamic error) {
    return _permanentAuthExceptionTypes
        .any((type) => error.runtimeType == type);
  }

  /// Checks if the error is a temporary (retryable) error
  static bool _isTemporaryError(dynamic error, String errorString) {
    // Check exception types
    if (_temporaryExceptionTypes.any((type) => error.runtimeType == type)) {
      return true;
    }

    // Check error string patterns
    return _temporaryErrorPatterns.any(
      (pattern) => errorString.contains(pattern),
    );
  }

  /// Checks if the error is a permanent client error (4xx, excluding 429)
  static bool _isPermanentClientError(String errorString) {
    return errorString.contains('Client error') && !errorString.contains('429');
  }
}

/// Enum representing different types of upload errors
enum UploadErrorType {
  temporary,
  permanentAuth,
  permanentClient,
}

class DirectUploadService {
  final String instanceId = DateTime.now().millisecondsSinceEpoch.toString();
  final OpenSenseMapService openSenseMapService;
  final SettingsBloc settingsBloc;
  final SenseBox senseBox;
  final OpenSenseMapBloc openSenseMapBloc;
  final UploadDataPreparer _dataPreparer;
  
  Function(List<GeolocationData>)? _onUploadSuccess;
  Function()? _onPermanentDisable;

  final ValueNotifier<bool> permanentUploadLossNotifier =
      ValueNotifier<bool>(false);

  Timer? _restartTimer;
  int _restartAttempts = 0;
  static const int maxRestartAttempts = 3;
  static const int baseRestartDelayMinutes = 1; 
  
  final List<Map<String, dynamic>> _directUploadBuffer = [];
  final Map<GeolocationData, Map<String, List<double>>> _accumulatedSensorData =
      {};
  bool _isEnabled = false;
  bool _isPermanentlyDisabled = false;
  bool _isUploadDisabled = false; // New flag for upload-only disabling
  Timer? _uploadTimer;

  DirectUploadService({
    required this.openSenseMapService,
    required this.settingsBloc,
    required this.senseBox,
    required this.openSenseMapBloc,
  }) : _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  void enable() {
    if (_restartTimer != null) {
      _restartTimer?.cancel();
      _restartTimer = null;
    }
    
    _isEnabled = true;
    _isPermanentlyDisabled = false;
    _isUploadDisabled = false; // Reset upload flag
    
    _resetRestartAttempts();
    _clearAllBuffersForNewRecording();
    _startPeriodicUploadCheck();

    debugPrint('[DirectUploadService] Service enabled, restart attempts reset');
  }

  void disable() {
    _isEnabled = false;
    _isPermanentlyDisabled = true;
    _isUploadDisabled = true; // Set upload flag
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  void disableTemporarily() {
    _isEnabled = false;
    _isUploadDisabled = true; // Set upload flag
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  bool get isEnabled => _isEnabled;
  bool get permanentlyDisabled => _isPermanentlyDisabled;
  bool get isUploadDisabled => _isUploadDisabled;
  bool get hasPreservedData => _accumulatedSensorData.isNotEmpty;
  bool get hasPendingRestartTimer => _restartTimer != null;

  void setUploadSuccessCallback(Function(List<GeolocationData>) callback) {
    _onUploadSuccess = callback;
  }

  void setPermanentDisableCallback(Function() callback) {
    _onPermanentDisable = callback;
  }

  bool addGroupedDataForUpload(
      Map<GeolocationData, Map<String, List<double>>> groupedData,
      List<GeolocationData> gpsBuffer) {
    // Accept data for local storage even if uploads are disabled
    if (!_isEnabled) {
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

    // Don't prepare data if service is permanently disabled
    if (_isPermanentlyDisabled) {
      return;
    }

    // Create a snapshot of current data to ensure atomic operation
    final Map<GeolocationData, Map<String, List<double>>> dataSnapshot =
        Map.from(_accumulatedSensorData);
    final List<GeolocationData> gpsPointsBeingUploaded =
        dataSnapshot.keys.toList();
    
    final uploadData = _dataPreparer.prepareDataFromGroupedData(
        dataSnapshot, gpsBuffer);
    final uploadDataWithGps = {
      'data': uploadData,
      'gpsPoints': gpsPointsBeingUploaded,
    };

    _directUploadBuffer.add(uploadDataWithGps);
    
    // Only clear the exact data that was prepared for upload
    for (final gpsPoint in gpsPointsBeingUploaded) {
      _accumulatedSensorData.remove(gpsPoint);
    }

    if (_directUploadBuffer.length >= 6) {
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

  void _prepareAndUploadDataSync(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) {
      return;
    }

    // Don't prepare data if service is permanently disabled
    if (_isPermanentlyDisabled) {
      return;
    }

    // Create a snapshot of current data to ensure atomic operation
    final Map<GeolocationData, Map<String, List<double>>> dataSnapshot =
        Map.from(_accumulatedSensorData);
    final List<GeolocationData> gpsPointsBeingUploaded =
        dataSnapshot.keys.toList();
    
    final uploadData = _dataPreparer.prepareDataFromGroupedData(
        dataSnapshot, gpsBuffer);
    final uploadDataWithGps = {
      'data': uploadData,
      'gpsPoints': gpsPointsBeingUploaded,
    };

    _directUploadBuffer.add(uploadDataWithGps);
    
    // Only clear the exact data that was prepared for upload
    for (final gpsPoint in gpsPointsBeingUploaded) {
      _accumulatedSensorData.remove(gpsPoint);
    }
  }

  Future<void> uploadRemainingBufferedData() async {
    // Always clear accumulated sensor data first to prevent memory leaks
    if (_accumulatedSensorData.isNotEmpty) {
      final gpsBuffer = _accumulatedSensorData.keys.toList();
      _prepareAndUploadDataSync(gpsBuffer);
    } 

    if (_directUploadBuffer.isNotEmpty) {
      try {
        await _uploadDirectBufferSync();
        
        // Clear buffers after successful upload
        _accumulatedSensorData.clear();
        _directUploadBuffer.clear();
        
      } catch (e, st) {
        // Check if it's a non-critical error that should preserve data
        final isNonCriticalError = e is TooManyRequestsException ||
            e.toString().contains('Server error') ||
            e.toString().contains('Token refreshed') ||
            e is TimeoutException;

        if (!isNonCriticalError) {
          ErrorService.handleError(
              'Direct upload failed during recording stop at ${DateTime.now()}: $e. Data cleared due to permanent error.',
              st,
              sendToSentry: true);
          // Clear buffers on permanent errors
          _accumulatedSensorData.clear();
          _directUploadBuffer.clear();
        }
      }
    } else {
      // No direct upload buffer data, but accumulated sensor data was already cleared above
      // This prevents the memory leak where accumulated data wasn't cleared
    }
  }

  Future<void> _uploadDirectBuffer() async {
    if (_directUploadBuffer.isEmpty) {
      return;
    }

    // Don't attempt uploads if service is permanently disabled
    if (_isPermanentlyDisabled) {
      return;
    }

    // Check if service is rate limited or permanently disabled
    if (!openSenseMapService.isAcceptingRequests) {
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

      await openSenseMapBloc.uploadData(senseBox.id, data);
      
      _directUploadBuffer.clear();
      _onUploadSuccess?.call(allGpsPoints);
    } catch (e, st) {
      final isNonCriticalError = e is TooManyRequestsException ||
          e.toString().contains('Server error') ||
          e.toString().contains('Token refreshed') ||
          e is TimeoutException;

      if (!isNonCriticalError) {
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
    _isUploadDisabled = true; // New flag
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _clearAllBuffers();
    permanentUploadLossNotifier.value = true;
  }

  void _scheduleRestart() {
    // Don't schedule restart if service is already enabled
    if (_isEnabled && !_isPermanentlyDisabled) {
      return;
    }
    
    if (_restartAttempts >= maxRestartAttempts) {
      _isUploadDisabled = true; // Set upload flag when max attempts reached

      // Notify sensors to clear their buffers since service is permanently disabled
      _onPermanentDisable?.call();
      
      return;
    }

    _restartAttempts++;
    final delayMinutes = baseRestartDelayMinutes * _restartAttempts; 

    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(minutes: delayMinutes), () {
      _attemptRestart();
    });
  }

  void _resetRestartAttempts() {
    _restartAttempts = 0;
    _restartTimer?.cancel();
    _restartTimer = null;
    _isUploadDisabled = false; // Reset upload flag
  }


  Future<void> _handleUploadError(dynamic e, StackTrace st) async {
    final errorString = e.toString();

    if (errorString.contains('Token refreshed')) {
      return;
    }

    // Since the bloc now handles authentication, we only need to handle
    // non-authentication errors here
    if (errorString.contains('Not authenticated') ||
        errorString.contains('Authentication failed') ||
        errorString.contains('No refresh token found') ||
        errorString.contains('Refresh token is expired')) {
      // Authentication errors are handled by the bloc, just log them
      ErrorService.handleError(
          'Direct upload authentication error at ${DateTime.now()}: $e. Handled by bloc.',
          st,
          sendToSentry: false);
      return;
    }
    
    // Handle other types of errors
    if (errorString.contains('Client error') && !errorString.contains('429')) {
      await _handlePermanentClientError(e, st);
    } else {
      // Treat as temporary error
      ErrorService.handleError(
          'Direct upload temporary error at ${DateTime.now()}: $e. Data preserved for retry.',
          st,
          sendToSentry: false);
    }
  }





  void _permanentlyDisableService() {
    _isEnabled = false;
    _isPermanentlyDisabled = true;
    _isUploadDisabled = true; // New flag
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;
    permanentUploadLossNotifier.value = true;
    _onPermanentDisable?.call();
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
    if (_isEnabled && !_isPermanentlyDisabled) {
      return;
    }

    if (_directUploadBuffer.isNotEmpty) {
      _uploadDirectBuffer().then((_) {
        // Success - data uploaded, now restart
        _clearAllBuffers();
        _isEnabled = true;
        _isPermanentlyDisabled = false;
        _isUploadDisabled = false; // Reset upload flag
        permanentUploadLossNotifier.value = false;
      }).catchError((e) {
        // Don't clear buffers - preserve data for next attempt
        _isEnabled = true;
        _isPermanentlyDisabled = false;
        _isUploadDisabled = false; // Reset upload flag
        permanentUploadLossNotifier.value = false;
      });
    } else {
      // No data to upload, restart immediately
      _clearAllBuffers();
      _isEnabled = true;
      _isPermanentlyDisabled = false;
      _isUploadDisabled = false; // Reset upload flag
      permanentUploadLossNotifier.value = false;
    }
  }

  Future<void> _uploadDirectBufferSync() async {
    if (_directUploadBuffer.isEmpty) return;

    // Don't attempt uploads if service is permanently disabled
    if (_isPermanentlyDisabled) {
      return;
    }

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

      await openSenseMapBloc.uploadData(senseBox.id, data);

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
    _uploadTimer = Timer.periodic(Duration(seconds: 10), (_) async {
      // Don't run periodic checks if service is permanently disabled
      if (_isPermanentlyDisabled) {
        return;
      }
      
      // Try to upload any buffered data if service is accepting requests
      if (_directUploadBuffer.isNotEmpty &&
          openSenseMapService.isAcceptingRequests) {
        // _logBufferStatus();
        _uploadDirectBuffer().catchError((e) {
        });
      } else if (_directUploadBuffer.isNotEmpty &&
          openSenseMapService.isPermanentlyDisabled) {
      }
    });
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