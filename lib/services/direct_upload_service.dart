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

class DirectUploadService {
  final String instanceId = DateTime.now().millisecondsSinceEpoch.toString();
  final OpenSenseMapService openSenseMapService;
  final SettingsBloc settingsBloc;
  final SenseBox senseBox;
  final UploadDataPreparer _dataPreparer;

  // vars to handle connectivity issues
  DateTime? _lastSuccessfulUpload;
  int _consecutiveFails = 0;

  // Buffer for direct uploads - stores prepared data maps
  final List<Map<String, dynamic>> _directUploadBuffer = [];
  bool _isEnabled = false;
  
  // Direct upload retry mechanism
  Timer? _directUploadRetryTimer;
  bool _isDirectUploading = false;
  int _directUploadRetryCount = 0;
  static const int _maxDirectUploadRetries = 5;
  static const Duration _directUploadRetryDelay = Duration(minutes: 2);

  DirectUploadService({
    required this.openSenseMapService,
    required this.settingsBloc,
    required this.senseBox,
  }) : _dataPreparer = UploadDataPreparer(senseBox: senseBox) {}

  void enable() {
    _isEnabled = true;
  }

  void disable() {
    _isEnabled = false;
    
    _directUploadRetryTimer?.cancel();
    _directUploadRetryTimer = null;
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

  Future<void> uploadRemainingBufferedData() async {
    if (_directUploadBuffer.isNotEmpty) {
      await _uploadDirectBuffer();
    }
  }

  Future<void> _uploadDirectBuffer() async {
    if (_directUploadBuffer.isEmpty || _isDirectUploading) return;

    _isDirectUploading = true;
    
    try {
      // Merge all prepared data maps into one
      final Map<String, dynamic> data = {};
      for (final preparedData in _directUploadBuffer) {
        data.addAll(preparedData);
      }

      await _uploadDirectBufferWithRetry(data);
      // Only clear the buffer after successful upload
      _directUploadBuffer.clear();
      // Track successful upload
      _lastSuccessfulUpload = DateTime.now();
      _consecutiveFails = 0;
      _directUploadRetryCount = 0;
    } catch (e) {
      // Do NOT clear the buffer here; keep it for the next retry
      _consecutiveFails++;
      _directUploadRetryCount++;
      final lastSuccessfulUploadPeriod = DateTime.now()
          .subtract(Duration(minutes: premanentConnectivityFalurePeriod));
      final isPermanentConnectivityIssue =
          _lastSuccessfulUpload != null &&
              _lastSuccessfulUpload!.isBefore(lastSuccessfulUploadPeriod);
      final isMaxRetries = _consecutiveFails >= maxRetries;
      final isMaxDirectUploadRetries =
          _directUploadRetryCount >= _maxDirectUploadRetries;
      if (isPermanentConnectivityIssue || isMaxRetries || isMaxDirectUploadRetries) {
        ErrorService.handleError(
            'Permanent connectivity failure: No connection for more than $premanentConnectivityFalurePeriod minutes or max retries exceeded.',
            StackTrace.current);
        return;
      } else {
        // Schedule retry for direct upload
        _scheduleDirectUploadRetry();
      }
    } finally {
      _isDirectUploading = false;
    }
  }

  Future<void> _uploadDirectBufferWithRetry(Map<String, dynamic> data) async {
    // Use the same retry configuration as the original OpenSenseMap service
    final r = RetryOptions(
      maxAttempts: 6, // 6 attempts per minute
      delayFactor: const Duration(seconds: 10), // 10s between attempts
      maxDelay: const Duration(seconds: 15),
    );

    await r.retry(
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

  void _scheduleDirectUploadRetry() {
    _directUploadRetryTimer?.cancel();
    _directUploadRetryTimer = Timer(_directUploadRetryDelay, () {
      if (_directUploadBuffer.isNotEmpty && _isEnabled) {
        _uploadDirectBuffer();
      }
    });
  }

  void dispose() {
    _directUploadRetryTimer?.cancel();
    _directUploadRetryTimer = null;
    _isDirectUploading = false;
    _directUploadBuffer.clear();
  }
} 