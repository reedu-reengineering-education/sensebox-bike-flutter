import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
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

  // vars to handle connectivity issues (same as LiveUploadService)
  DateTime? _lastSuccessfulUpload;
  int _consecutiveFails = 0;

  // Buffer for direct uploads - stores prepared data maps
  final List<Map<String, dynamic>> _directUploadBuffer = [];
  // Buffer for accumulating sensor data before preparing upload
  final Map<GeolocationData, Map<String, List<double>>> _accumulatedSensorData =
      {};
  bool _isEnabled = false;
  bool _isManuallyDisabled = false;
  Timer? _uploadTimer;
  Timer? _restartTimer;

  DirectUploadService({
    required this.openSenseMapService,
    required this.settingsBloc,
    required this.senseBox,
  }) : _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  void enable() {
    _isEnabled = true;
    _isManuallyDisabled = false;
    // Start timer to ensure data gets uploaded even with few GPS points
    // Reduced timer to 15 seconds for more frequent uploads
    _uploadTimer = Timer.periodic(Duration(seconds: 15), (_) {
      if (_accumulatedSensorData.isNotEmpty) {
        _prepareAndUploadData([]);
      }
    });
  }

  void disable() {
    _isEnabled = false;
    _isManuallyDisabled = true;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  bool get isEnabled => _isEnabled;

  void setUploadSuccessCallback(Function(List<GeolocationData>) callback) {
    _onUploadSuccess = callback;
  }

  void _scheduleRestart() {
    // Cancel any existing restart timer
    _restartTimer?.cancel();

    // Schedule restart after 5 minutes
    _restartTimer = Timer(Duration(seconds: 30), () {
      if (!_isEnabled && !_isManuallyDisabled) {
        ErrorService.handleError(
            'Direct upload: Auto-restarting service after API error timeout.',
            StackTrace.current,
            sendToSentry: true);
        enable();
      }
    });
  }



  bool addGroupedDataForUpload(
      Map<GeolocationData, Map<String, List<double>>> groupedData,
      List<GeolocationData> gpsBuffer) {
    if (!_isEnabled) return false;

    // Accumulate sensor data from all sensors
    for (final entry in groupedData.entries) {
      final GeolocationData geolocation = entry.key;
      final Map<String, List<double>> sensorData = entry.value;

      // Initialize geolocation entry if not exists
      _accumulatedSensorData.putIfAbsent(geolocation, () => {});

      // Add all sensor data for this geolocation
      _accumulatedSensorData[geolocation]!.addAll(sensorData);
    }

    // Check if we have enough data to upload (adaptive threshold)
    // Upload immediately if we have 3+ GPS points, or if we have 2+ points and timer hasn't fired recently
    final bool shouldUpload = _accumulatedSensorData.length >= 3 ||
        (_accumulatedSensorData.length >= 2 && _uploadTimer != null);

    if (shouldUpload) {
      _prepareAndUploadData(gpsBuffer);
    }
    
    return true; // Data was successfully added to buffer
  }

  void _prepareAndUploadData(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) return;

    // Store the GPS points that are being uploaded
    final List<GeolocationData> gpsPointsBeingUploaded =
        _accumulatedSensorData.keys.toList();

    // Prepare upload data from accumulated sensor data
    final uploadData = _dataPreparer.prepareDataFromGroupedData(
        _accumulatedSensorData, gpsBuffer);
    _directUploadBuffer.add(uploadData);

    // Upload if buffer is ready
    if (_directUploadBuffer.length >= 10) {
      _uploadDirectBuffer().then((_) {
        // Notify success callback with the GPS points that were uploaded
        _onUploadSuccess?.call(gpsPointsBeingUploaded);
      }).catchError((e) {
        // Upload failed, don't notify success callback
        // Data will be retried on next flush
      });
    }
  }

  Future<void> uploadRemainingBufferedData() async {
    // Force upload of any remaining accumulated sensor data
    if (_accumulatedSensorData.isNotEmpty) {
      _prepareAndUploadData([]);
    }

    // Upload any remaining buffered data
    if (_directUploadBuffer.isNotEmpty) {
      await _uploadDirectBuffer();
    }
    
    // If there's still accumulated data after upload attempts, report it
    if (_accumulatedSensorData.isNotEmpty) {
      ErrorService.handleError(
          'Direct upload: ${_accumulatedSensorData.length} GPS points still in buffer after upload attempts. Data may be lost.',
          StackTrace.current,
          sendToSentry: true);
    }
  }

  Future<void> _uploadDirectBuffer() async {
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
      // Report API errors to Sentry for tracking missing data
      ErrorService.handleError(
          'Direct upload API error: $e. Data buffers preserved for retry.', st,
          sendToSentry: true);
      
      // Check if this is a true authentication failure (no refresh token or invalid refresh token)
      if (e.toString().contains('No refresh token found') ||
          e.toString().contains('Failed to refresh token')) {
        // User is truly not authenticated, disable direct upload
        disable();
        ErrorService.handleError(
            'Direct upload disabled: User not authenticated. Please log in to enable direct upload.',
            st,
            sendToSentry: false);
        return;
      }

      // Handle other upload errors (same logic as LiveUploadService)
      _consecutiveFails++;
      
      final lastSuccessfulUploadPeriod = DateTime.now()
          .subtract(Duration(minutes: premanentConnectivityFalurePeriod));
      final isPermanentConnectivityIssue = _lastSuccessfulUpload != null &&
          _lastSuccessfulUpload!.isBefore(lastSuccessfulUploadPeriod);
      final isMaxRetries = _consecutiveFails >= maxRetries;

      if (isPermanentConnectivityIssue || isMaxRetries) {
        final message = isPermanentConnectivityIssue
            ? 'Permanent connectivity failure: No connection for more than $premanentConnectivityFalurePeriod minutes.'
            : 'Permanent connectivity failure: Max retries ($maxRetries) exceeded.';
        ErrorService.handleError(message, st, sendToSentry: true);
        
        // Instead of permanently disabling, schedule a restart
        _isEnabled = false;
        _uploadTimer?.cancel();
        _uploadTimer = null;
        _scheduleRestart();
      } else {
        // For temporary errors, also schedule a restart after a shorter timeout
        _scheduleRestart();
      }
    } finally {
      _isDirectUploading = false;
    }
  }

  Future<void> _uploadDirectBufferWithRetry(Map<String, dynamic> data) async {
    // Let OpenSenseMapService handle token refresh automatically
    // It will refresh tokens on 401 errors and retry the request
    await openSenseMapService.uploadData(senseBox.id, data);
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

  // Internal flag to prevent concurrent uploads
  bool _isDirectUploading = false;
} 