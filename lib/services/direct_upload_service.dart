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
    
    // Check if there's any accumulated data to upload immediately
    if (_accumulatedSensorData.isNotEmpty) {
      debugPrint(
          'Direct upload: Service re-enabled, uploading ${_accumulatedSensorData.length} preserved GPS points');
      final gpsBuffer = _accumulatedSensorData.keys.toList();
      _prepareAndUploadData(gpsBuffer);

      // Force immediate upload of preserved data regardless of buffer thresholds
      if (_directUploadBuffer.isNotEmpty) {
        _uploadDirectBuffer().catchError((e) {
          debugPrint(
              'Failed to upload preserved data on service re-enable: $e');
        });
      }
    }
    
    // Start timer to ensure data gets uploaded even with few GPS points
    _uploadTimer = Timer.periodic(Duration(seconds: 15), (_) {
      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Timer fired, accumulated data: ${_accumulatedSensorData.length}');
      if (_accumulatedSensorData.isNotEmpty) {
        _prepareAndUploadData([]);
      }
    });
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
    // Always accept data unless permanently disabled
    // This allows data to be accumulated even when service is temporarily disabled
    if (_isPermanentlyDisabled) return false;

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

    // Always accumulate data, but only attempt upload if service is enabled
    if (_isEnabled) {
      // Check if we have enough data to upload (threshold-based)
      // Upload immediately if we have 3+ GPS points
      final bool shouldUpload = _accumulatedSensorData.length >= 3;

      debugPrint(
          '[${DateTime.now().toString()}] Direct upload: Upload threshold check - accumulated: ${_accumulatedSensorData.length}, shouldUpload: $shouldUpload');

      if (shouldUpload) {
        _prepareAndUploadData(gpsBuffer);
        // Clear accumulated data immediately after preparing for upload
        // This prevents the same GPS points from being processed multiple times
        _accumulatedSensorData.clear();
      }
    } else {
      // Service is temporarily disabled, just accumulate data for later
      debugPrint(
          'Direct upload: Service temporarily disabled, accumulating data for later upload');
    }
    
    return true; // Data was successfully added to buffer
  }

  void _prepareAndUploadData(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) return;

    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Preparing upload for ${_accumulatedSensorData.length} GPS points, buffer size: ${_directUploadBuffer.length}');

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
    // Force upload of any remaining accumulated sensor data
    if (_accumulatedSensorData.isNotEmpty) {
      // Use the GPS points from _accumulatedSensorData instead of empty list
      final gpsBuffer = _accumulatedSensorData.keys.toList();
      _prepareAndUploadDataSync(gpsBuffer);
    }

    // Force upload even if buffer threshold is not met (for testing and final flush)
    if (_directUploadBuffer.isNotEmpty) {
      try {
        await _uploadDirectBufferSync();
      } catch (e, st) {
        // Upload failed during recording stop - preserve data for next session
        ErrorService.handleError(
            'Direct upload failed during recording stop at ${DateTime.now()}: $e. Data preserved for next session.',
            st,
            sendToSentry: true);
        return; // Don't clear buffers on upload failure
      }
    }
    
    // Only report remaining data if upload was successful
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

    debugPrint(
        '[${DateTime.now().toString()}] Direct upload: Starting upload of ${_directUploadBuffer.length} buffers');

    try {
      // Merge all prepared data maps into one
      final Map<String, dynamic> data = {};
      for (final preparedData in _directUploadBuffer) {
        data.addAll(preparedData);
      }

      if (data.isEmpty) return;

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
      // Check if this is an authentication error that should be handled by OpenSenseMapService
      if (e.toString().contains('Not authenticated') ||
          e.toString().contains('401 Unauthorized')) {
        // Authentication errors are handled by OpenSenseMapService (token refresh)
        // Don't disable the service, just report and continue
        ErrorService.handleError(
            'Direct upload authentication error at ${DateTime.now()}: $e. Will retry after token refresh.',
            st,
            sendToSentry: false);
        // Don't return here - let the finally block reset _isDirectUploading
      } else {
        // Report API errors to Sentry for tracking missing data
        ErrorService.handleError(
            'Direct upload API error at ${DateTime.now()}: $e. Data buffers preserved for retry.',
            st,
            sendToSentry: true);
        


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

          // Permanently disable for connectivity issues
          _isEnabled = false;
          _isPermanentlyDisabled = true;
          _uploadTimer?.cancel();
          _uploadTimer = null;
          permanentUploadLossNotifier.value = true;
          ErrorService.handleError(UploadFailureError(), st,
              sendToSentry: true);
        } else {
          // For temporary errors, just disable temporarily
          disableTemporarily();
        }
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
      // Check if this is an authentication error that should be handled by OpenSenseMapService
      if (e.toString().contains('Not authenticated') ||
          e.toString().contains('401 Unauthorized')) {
        // Authentication errors are handled by OpenSenseMapService (token refresh)
        // Don't disable the service, just report and continue
        ErrorService.handleError(
            'Direct upload authentication error at ${DateTime.now()}: $e. Will retry after token refresh.',
            st,
            sendToSentry: false);
        // Don't return here - let the finally block reset _isDirectUploading
      } else {
        // Report API errors to Sentry for tracking missing data
        ErrorService.handleError(
            'Direct upload API error at ${DateTime.now()}: $e. Data buffers preserved for retry.',
            st,
            sendToSentry: true);



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

          // Permanently disable for connectivity issues
        _isEnabled = false;
          _isPermanentlyDisabled = true;
        _uploadTimer?.cancel();
        _uploadTimer = null;
          permanentUploadLossNotifier.value = true;
          ErrorService.handleError(UploadFailureError(), st,
              sendToSentry: true);
      } else {
          // For temporary errors, just disable temporarily
          disableTemporarily();
        }
      }
    } finally {
      _isDirectUploading = false;
    }
  }

  void dispose() {
    _isDirectUploading = false;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _directUploadBuffer.clear();
    _accumulatedSensorData.clear();
    permanentUploadLossNotifier.dispose();
  }

  // Internal flag to prevent concurrent uploads
  bool _isDirectUploading = false;
} 