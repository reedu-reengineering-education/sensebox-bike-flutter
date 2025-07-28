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

  // vars to handle connectivity issues (same as LiveUploadService)
  DateTime? _lastSuccessfulUpload;
  int _consecutiveFails = 0;

  // Buffer for direct uploads - stores prepared data maps
  final List<Map<String, dynamic>> _directUploadBuffer = [];
  // Buffer for accumulating sensor data before preparing upload
  final Map<GeolocationData, Map<String, List<double>>> _accumulatedSensorData =
      {};
  bool _isEnabled = false;

  DirectUploadService({
    required this.openSenseMapService,
    required this.settingsBloc,
    required this.senseBox,
  }) : _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  void enable() {
    _isEnabled = true;
  }

  void disable() {
    _isEnabled = false;
  }

  bool get isEnabled => _isEnabled;

  void addGroupedDataForUpload(
      Map<GeolocationData, Map<String, List<double>>> groupedData,
      List<GeolocationData> gpsBuffer) {
    if (!_isEnabled) return;

    // Accumulate sensor data from all sensors
    for (final entry in groupedData.entries) {
      final GeolocationData geolocation = entry.key;
      final Map<String, List<double>> sensorData = entry.value;

      // Initialize geolocation entry if not exists
      _accumulatedSensorData.putIfAbsent(geolocation, () => {});

      // Add all sensor data for this geolocation
      _accumulatedSensorData[geolocation]!.addAll(sensorData);
    }

    // Debug logging to track data accumulation
    debugPrint(
        'DirectUploadService: Accumulated data for ${_accumulatedSensorData.length} GPS points');

    // Check if we have enough data to upload (either by buffer size or time)
    if (_accumulatedSensorData.length >= 5) {
      _prepareAndUploadData(gpsBuffer);
    }
  }

  void _prepareAndUploadData(List<GeolocationData> gpsBuffer) {
    if (_accumulatedSensorData.isEmpty) return;

    // Prepare upload data from accumulated sensor data
    final uploadData = _dataPreparer.prepareDataFromGroupedData(
        _accumulatedSensorData, gpsBuffer);
    _directUploadBuffer.add(uploadData);

    // Clear accumulated data after preparing upload
    _accumulatedSensorData.clear();

    // Upload if buffer is ready
    if (_directUploadBuffer.length >= 10) {
      _uploadDirectBuffer();
    }
  }

  Future<void> uploadRemainingBufferedData() async {
    // Force upload of any remaining accumulated sensor data
    if (_accumulatedSensorData.isNotEmpty) {
      debugPrint(
          'DirectUploadService: Uploading remaining accumulated data for ${_accumulatedSensorData.length} GPS points');
      _prepareAndUploadData([]);
    }

    // Upload any remaining buffered data
    if (_directUploadBuffer.isNotEmpty) {
      await _uploadDirectBuffer();
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
      // Only clear the buffer after successful upload
      _directUploadBuffer.clear();
      // Track successful upload
      _lastSuccessfulUpload = DateTime.now();
      _consecutiveFails = 0;
    } catch (e, st) {
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
        ErrorService.handleError(message, st);
        disable(); // Disable service on permanent failure
      } else {
        // Log retry attempt (same as LiveUploadService)
        debugPrint(
            'Failed to upload data: $e. Retrying in $retryPeriod minutes (Attempt $_consecutiveFails of $maxRetries).');
        // Note: We don't delay here since this is called from sensor buffer flush
        // The delay will happen naturally when the next buffer flush occurs
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
    _directUploadBuffer.clear();
  }

  // Internal flag to prevent concurrent uploads
  bool _isDirectUploading = false;
} 