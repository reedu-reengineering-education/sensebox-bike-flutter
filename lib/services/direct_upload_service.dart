import 'dart:async';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/upload_data_preparer.dart';
import "package:sensebox_bike/constants.dart";
import 'package:retry/retry.dart';
import 'package:flutter/foundation.dart';

class DirectUploadService {
  final String instanceId = DateTime.now().millisecondsSinceEpoch.toString();
  final OpenSenseMapService openSenseMapService;
  final SettingsBloc settingsBloc;
  final SenseBox senseBox;
  final UploadDataPreparer _dataPreparer;
  final RetryOptions _retryOptions;

  // vars to handle connectivity issues
  DateTime? _lastSuccessfulUpload;
  int _consecutiveFails = 0;

  // Buffer for direct uploads - stores prepared data maps
  final List<Map<String, dynamic>> _directUploadBuffer = [];
  bool _isEnabled = false;

  DirectUploadService({
    required this.openSenseMapService,
    required this.settingsBloc,
    required this.senseBox,
    RetryOptions? retryOptions,
  })  : _dataPreparer = UploadDataPreparer(senseBox: senseBox),
        _retryOptions = retryOptions ??
            const RetryOptions(
              maxAttempts: 6,
              delayFactor: Duration(seconds: 10),
              maxDelay: Duration(seconds: 30),
            );

  void enable() {
    _isEnabled = true;
  }

  void disable() {
    _isEnabled = false;
  }

  bool get isEnabled => _isEnabled;

  void addBufferedDataForUpload(List<Map<String, dynamic>> sensorBuffer, List<GeolocationData> gpsBuffer) {
    if (!_isEnabled) return;

    final uploadData = _dataPreparer.prepareDataFromBuffers(
        List.from(sensorBuffer), List.from(gpsBuffer));
    _directUploadBuffer.add(uploadData);

    if (_directUploadBuffer.length >= 10) {
      _uploadDirectBuffer();
    }
  }

  /// Add grouped sensor data for upload (more efficient - avoids duplicate grouping)
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
      // Do NOT clear the buffer here; keep it for the next retry
      _consecutiveFails++;

      // Check if we should treat this as a permanent connectivity issue
      bool isPermanentConnectivityIssue = false;
      bool isMaxRetries = _consecutiveFails >= maxRetries;

      if (_lastSuccessfulUpload != null) {
        final lastSuccessfulUploadPeriod = DateTime.now()
            .subtract(Duration(minutes: premanentConnectivityFalurePeriod));
        isPermanentConnectivityIssue =
            _lastSuccessfulUpload!.isBefore(lastSuccessfulUploadPeriod);
      } else {
        // If we've never had a successful upload and we've failed many times,
        // it might be a permanent issue, but we should give it more chances
        isPermanentConnectivityIssue = _consecutiveFails >= maxRetries * 2;
      }
      
      if (isPermanentConnectivityIssue || isMaxRetries) {
        final message = isPermanentConnectivityIssue
            ? 'Permanent connectivity failure: No connection for more than $premanentConnectivityFalurePeriod minutes.'
            : 'Permanent connectivity failure: Max retries ($maxRetries) exceeded.';
        ErrorService.handleError(message, st);
      } else {
        // No custom retry, just leave buffer for next attempt
      }
    } finally {
      _isDirectUploading = false;
    }
  }

  Future<void> _uploadDirectBufferWithRetry(Map<String, dynamic> data) async {
    await _retryOptions.retry(
      () async {
        await openSenseMapService.uploadData(senseBox.id, data);
      },
      retryIf: (e) =>
          e is TooManyRequestsException ||
          e.toString().contains('Token refreshed') ||
          e is TimeoutException,
      onRetry: (e) async {
        if (e is TooManyRequestsException) {
          await Future.delayed(Duration(seconds: e.retryAfter));
        }
      },
    );
  }

  void dispose() {
    _isDirectUploading = false;
    _directUploadBuffer.clear();
  }

  // Internal flag to prevent concurrent uploads
  bool _isDirectUploading = false;
} 