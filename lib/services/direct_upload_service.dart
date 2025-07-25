import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/upload_data_preparer.dart';
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

    final uploadData =
        _dataPreparer.prepareDataFromGroupedData(groupedData, gpsBuffer);
    _directUploadBuffer.add(uploadData);

    if (_directUploadBuffer.length >= 10) {
      _uploadDirectBuffer();
    }
  }

  Future<void> uploadRemainingBufferedData() async {
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
      // Handle upload error (same logic as LiveUploadService)
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
    try {
      await openSenseMapService.uploadData(senseBox.id, data);
    } catch (e) {
      // Handle authentication errors gracefully
      if (e.toString().contains('Not authenticated') ||
          e.toString().contains('401')) {
        // User is not authenticated, disable direct upload and log the issue
        disable();
        ErrorService.handleError(
            'Direct upload disabled: User not authenticated. Please log in to enable direct upload.',
            StackTrace.current,
            sendToSentry: false);
        return;
      }
      // Re-throw other exceptions for error handling in _uploadDirectBuffer
      rethrow;
    }
  }

  void dispose() {
    _isDirectUploading = false;
    _directUploadBuffer.clear();
  }

  // Internal flag to prevent concurrent uploads
  bool _isDirectUploading = false;
} 