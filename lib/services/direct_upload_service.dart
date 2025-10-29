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
import 'package:sensebox_bike/services/isar_service/track_service.dart';

class UploadErrorClassifier {
  static const List<String> _permanentAuthErrorPatterns = [
    'Authentication failed - user needs to re-login',
    'No refresh token found',
    'Failed to refresh token: Authentication failed',
    'Failed to refresh token: Invalid token',
    'Not authenticated',
  ];

  static const List<String> _temporaryErrorPatterns = [
    'Failed to refresh token: Network error',
    'Server error',
    'Token refreshed',
    'Network error',
  ];

  static const List<Type> _temporaryExceptionTypes = [
    TooManyRequestsException,
    TimeoutException,
  ];

  static const List<Type> _permanentAuthExceptionTypes = [
    PermanentAuthenticationError,
  ];

  static UploadErrorType classifyError(dynamic error) {
    if (_isPermanentAuthExceptionType(error)) {
      return UploadErrorType.permanentAuth;
    }

    final errorString = error.toString();

    if (_isPermanentAuthError(errorString)) {
      return UploadErrorType.permanentAuth;
    }

    if (_isTemporaryError(error, errorString)) {
      return UploadErrorType.temporary;
    }

    if (_isPermanentClientError(errorString)) {
      return UploadErrorType.permanentClient;
    }

    return UploadErrorType.temporary;
  }

  static bool _isPermanentAuthError(String errorString) {
    // Check specific patterns first
    if (_permanentAuthErrorPatterns.any(
      (pattern) => errorString.contains(pattern),
    )) {
      return true;
    }

    // Check for generic "Failed to refresh token:" but exclude network errors
    if (errorString.contains('Failed to refresh token:') &&
        !errorString.contains('Failed to refresh token: Network error')) {
      return true;
    }

    return false;
  }

  static bool _isPermanentAuthExceptionType(dynamic error) {
    return _permanentAuthExceptionTypes
        .any((type) => error.runtimeType == type);
  }

  static bool _isTemporaryError(dynamic error, String errorString) {
    if (_temporaryExceptionTypes.any((type) => error.runtimeType == type)) {
      return true;
    }

    return _temporaryErrorPatterns.any(
      (pattern) => errorString.contains(pattern),
    );
  }

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
  final TrackService trackService;
  final int trackId;
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
  
  // Deferred data buffer for GPS-unavailable scenarios
  final Map<DateTime, Map<String, List<double>>> _deferredSensorData = {};
  final List<DateTime> _deferredDataTimestamps = [];
  static const int maxDeferredDataAge = 1; // hours - prevent indefinite storage
  
  bool _isEnabled = false;
  bool _isPermanentlyDisabled = false;
  bool _isUploadDisabled = false; // New flag for upload-only disabling
  Timer? _uploadTimer;

  DirectUploadService({
    required this.openSenseMapService,
    required this.settingsBloc,
    required this.senseBox,
    required this.openSenseMapBloc,
    required this.trackService,
    required this.trackId,
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
    
    return true;
  }

  void _prepareAndUploadData(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) {
      return;
    }

    if (_isPermanentlyDisabled) {
      return;
    }

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

    if (_directUploadBuffer.length >= 3) {
      _uploadDirectBuffer().catchError((e) {
        ErrorService.handleError(
            'Direct upload failed at ${DateTime.now()}: ${e.toString()}',
            StackTrace.current,
            sendToSentry: true);
      });
    }
  }

  void _prepareAndUploadDataSync(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) {
      return;
    }

    if (_isPermanentlyDisabled) {
      return;
    }

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
    
    for (final gpsPoint in gpsPointsBeingUploaded) {
      _accumulatedSensorData.remove(gpsPoint);
    }
  }

  Future<void> uploadRemainingBufferedData() async {
    if (_accumulatedSensorData.isNotEmpty) {
      final gpsBuffer = _accumulatedSensorData.keys.toList();
      _prepareAndUploadDataSync(gpsBuffer);
    } 

    if (_directUploadBuffer.isNotEmpty) {
      try {
        await _uploadDirectBufferSync();
        
        _accumulatedSensorData.clear();
        _directUploadBuffer.clear();
        
      } catch (e, st) {
        final isNonCriticalError = e is TooManyRequestsException ||
            e.toString().contains('Server error') ||
            e.toString().contains('Token refreshed') ||
            e is TimeoutException;

        if (!isNonCriticalError) {
          ErrorService.handleError(
              'Direct upload failed during recording stop at ${DateTime.now()}: $e. Data cleared due to permanent error.',
              st,
              sendToSentry: true);
          _accumulatedSensorData.clear();
          _directUploadBuffer.clear();
        }
      }
    }
  }

  Future<void> _uploadDirectBuffer() async {
    if (_directUploadBuffer.isEmpty) {
      return;
    }

    if (_isPermanentlyDisabled) {
      return;
    }

    if (!openSenseMapService.isAcceptingRequests) {
      return;
    }

    if (!openSenseMapBloc.isAuthenticated) {
      if (!_isPermanentlyDisabled) {
        await _handlePermanentAuthenticationError(
            Exception('User not authenticated'), StackTrace.current);
      }
      return;
    }

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
      
      // SUCCESS: Now clear both the upload buffer AND the corresponding accumulated data
      _directUploadBuffer.clear();
      
      // Clear the accumulated data that was successfully uploaded
      for (final gpsPoint in allGpsPoints) {
        _accumulatedSensorData.remove(gpsPoint);
      }

      _onUploadSuccess?.call(allGpsPoints);
    } catch (e, st) {
      final isNonCriticalError = e is TooManyRequestsException ||
          e.toString().contains('Server error') ||
          e.toString().contains('Token refreshed') ||
          e is TimeoutException;

      if (!isNonCriticalError) {
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
    _deferredSensorData.clear();
    _deferredDataTimestamps.clear();
  }

  void _clearAllBuffersForNewRecording() {
    _clearAllBuffers();
  }

  /// Stores sensor data when GPS is unavailable to prevent data loss
  void addDeferredSensorData(String sensorTitle, List<double> values) {
    final timestamp = DateTime.now();
    
    // Clean up old deferred data to prevent memory issues
    _cleanupOldDeferredData();
    
    if (!_deferredSensorData.containsKey(timestamp)) {
      _deferredSensorData[timestamp] = {};
      _deferredDataTimestamps.add(timestamp);
    }
    
    _deferredSensorData[timestamp]![sensorTitle] = values;
    
    debugPrint('[DirectUploadService] Deferred sensor data: $sensorTitle at $timestamp (GPS unavailable)');
  }

  /// Cleans up deferred data older than maxDeferredDataAge hours
  void _cleanupOldDeferredData() {
    final cutoffTime = DateTime.now().subtract(Duration(hours: maxDeferredDataAge));
    
    _deferredDataTimestamps.removeWhere((timestamp) {
      if (timestamp.isBefore(cutoffTime)) {
        _deferredSensorData.remove(timestamp);
        return true;
      }
      return false;
    });
  }

  void _disableAndClearBuffers() {
    _isEnabled = false;
    _isPermanentlyDisabled = true;
    _isUploadDisabled = true;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _clearAllBuffers();
    permanentUploadLossNotifier.value = true;
  }

  /// Processes deferred sensor data when GPS becomes available again
  void processDeferredDataWithGps(GeolocationData gpsPoint) {
    if (_deferredSensorData.isEmpty) {
      return;
    }

    debugPrint('[DirectUploadService] Processing ${_deferredSensorData.length} deferred data entries with new GPS point');
    
    // Find the closest timestamp to associate with the GPS point
    final gpsTimestamp = gpsPoint.timestamp;
    DateTime? closestTimestamp;
    Duration? smallestDifference;
    
    for (final timestamp in _deferredDataTimestamps) {
      final difference = (timestamp.difference(gpsTimestamp)).abs();
      if (smallestDifference == null || difference < smallestDifference) {
        smallestDifference = difference;
        closestTimestamp = timestamp;
      }
    }
    
    if (closestTimestamp != null && smallestDifference != null) {
      // Only associate if the difference is reasonable (within 5 minutes)
      if (smallestDifference.inMinutes <= 5) {
        final deferredData = _deferredSensorData[closestTimestamp]!;
        
        // Create a map entry for the GPS point with deferred data
        final Map<String, List<double>> combinedData = {};
        combinedData.addAll(deferredData);
        
        // Add to accumulated sensor data for upload
        _accumulatedSensorData[gpsPoint] = combinedData;
        
        // Remove the processed deferred data
        _deferredSensorData.remove(closestTimestamp);
        _deferredDataTimestamps.remove(closestTimestamp);
        
        debugPrint('[DirectUploadService] Associated deferred data with GPS point at ${gpsPoint.timestamp}');
      } else {
        debugPrint('[DirectUploadService] Deferred data too old (${smallestDifference.inMinutes} min) - discarding');
        // Clean up old deferred data
        _deferredSensorData.remove(closestTimestamp);
        _deferredDataTimestamps.remove(closestTimestamp);
      }
    }
  }

  void _scheduleRestart() {
    if (_isEnabled && !_isPermanentlyDisabled) {
      return;
    }
    
    if (_restartAttempts >= maxRestartAttempts) {
      _isUploadDisabled = true;

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

  // Getters for deferred data status
  bool get hasDeferredData => _deferredSensorData.isNotEmpty;
  int get deferredDataCount => _deferredSensorData.length;
  Duration? get oldestDeferredDataAge {
    if (_deferredDataTimestamps.isEmpty) return null;
    final oldest = _deferredDataTimestamps.reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime.now().difference(oldest);
  }

  /// Call this method when GPS becomes available to process deferred data
  void onGpsAvailable(GeolocationData gpsPoint) {
    if (hasDeferredData) {
      processDeferredDataWithGps(gpsPoint);
      debugPrint('[DirectUploadService] GPS available - processed deferred data');
    }
  }

  void _resetRestartAttempts() {
    _restartAttempts = 0;
    _restartTimer?.cancel();
    _restartTimer = null;
    _isUploadDisabled = false;
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
    
    final errorType = UploadErrorClassifier.classifyError(e);
    switch (errorType) {
      case UploadErrorType.permanentAuth:
        await _handlePermanentAuthenticationError(e, st);
        break;
      case UploadErrorType.permanentClient:
        await _handlePermanentClientError(e, st);
        break;
      case UploadErrorType.temporary:
        ErrorService.handleError(
            'Direct upload temporary error at ${DateTime.now()}: $e. Data preserved for retry.',
            st,
            sendToSentry: false);
        break;

    }
  }

  void _permanentlyDisableService() {
    _isEnabled = false;
    _isPermanentlyDisabled = true;
    _isUploadDisabled = true;
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

  Future<void> _handlePermanentAuthenticationError(
      dynamic e, StackTrace st) async {
    ErrorService.handleError(
        'Direct upload permanent authentication error at ${DateTime.now()}: $e. Service disabled.',
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
        _clearAllBuffers();
        _isEnabled = true;
        _isPermanentlyDisabled = false;
        _isUploadDisabled = false;
        permanentUploadLossNotifier.value = false;
      }).catchError((e) {
        _isEnabled = true;
        _isPermanentlyDisabled = false;
        _isUploadDisabled = false;
        permanentUploadLossNotifier.value = false;
      });
    } else {
      _clearAllBuffers();
      _isEnabled = true;
      _isPermanentlyDisabled = false;
      _isUploadDisabled = false;
      permanentUploadLossNotifier.value = false;
    }
  }

  Future<void> _uploadDirectBufferSync() async {
    if (_directUploadBuffer.isEmpty) return;

    if (_isPermanentlyDisabled) {
      return;
    }

    if (!openSenseMapBloc.isAuthenticated) {
      if (!_isPermanentlyDisabled) {
        await _handlePermanentAuthenticationError(
            Exception('User not authenticated'), StackTrace.current);
      }
      return;
    }

    if (_isDirectUploading) return;
    _isDirectUploading = true;

    try {
      final Map<String, dynamic> data = {};
      final List<GeolocationData> allGpsPoints = [];
      
      for (final uploadDataWithGps in _directUploadBuffer) {
        final uploadData = uploadDataWithGps['data'] as Map<String, dynamic>;
        final gpsPoints = uploadDataWithGps['gpsPoints'] as List<GeolocationData>;
        
        data.addAll(uploadData);
        allGpsPoints.addAll(gpsPoints);
      }

      if (data.isEmpty) return;

      await openSenseMapBloc.uploadData(senseBox.id, data);

      _directUploadBuffer.clear();

      for (final gpsPoint in allGpsPoints) {
        _accumulatedSensorData.remove(gpsPoint);
      }
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

  void _startPeriodicUploadCheck() {
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(Duration(seconds: 10), (_) async {
      if (_isPermanentlyDisabled) {
        return;
      }
      
      if (!openSenseMapBloc.isAuthenticated) {
        if (!_isPermanentlyDisabled) {
          _handlePermanentAuthenticationError(
                  Exception('User not authenticated'), StackTrace.current)
              .catchError((e) {});
        }
        return;
      }
      
      if (_directUploadBuffer.isNotEmpty &&
          openSenseMapService.isAcceptingRequests) {
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
    _deferredSensorData.clear();
    _deferredDataTimestamps.clear();
  }

  bool _isDirectUploading = false;
} 