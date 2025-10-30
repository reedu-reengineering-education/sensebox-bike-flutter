import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
import 'package:sensebox_bike/models/upload_batch.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';

class DirectUploadService {
  final OpenSenseMapService openSenseMapService;
  final SenseBox senseBox;
  final OpenSenseMapBloc openSenseMapBloc;
  final UploadDataPreparer _dataPreparer;
  
  Function(List<int>)? _onUploadSuccess;
  Function()? _onPermanentDisable;

  final ValueNotifier<bool> permanentUploadLossNotifier =
      ValueNotifier<bool>(false);
  
  final List<UploadBatch> _uploadQueue = [];
  
  bool _isEnabled = false;
  bool _isPermanentlyDisabled = false;
  bool _isUploadDisabled = false;
  bool _isUploading = false;
  Timer? _uploadTimer;

  DirectUploadService({
    required this.openSenseMapService,
    required this.senseBox,
    required this.openSenseMapBloc,
  }) : _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  void enable() {
    _isEnabled = true;
    _isPermanentlyDisabled = false;
    _isUploadDisabled = false;
    
    _clearAllBuffers();
    _startPeriodicUploadCheck();

    debugPrint('[DirectUploadService] Service enabled');
  }

  void disable() {
    _isEnabled = false;
    _isPermanentlyDisabled = true;
    _isUploadDisabled = true;
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  void disableTemporarily() {
    _isEnabled = false;
    _isUploadDisabled = true;
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  bool get isEnabled => _isEnabled;
  bool get permanentlyDisabled => _isPermanentlyDisabled;
  bool get isUploadDisabled => _isUploadDisabled;
  bool get hasPreservedData => _uploadQueue.isNotEmpty;

  void setUploadSuccessCallback(Function(List<int>) callback) {
    _onUploadSuccess = callback;
  }

  void setPermanentDisableCallback(Function() callback) {
    _onPermanentDisable = callback;
  }

  void queueBatchesForUpload(List<SensorBatch> batches) {
    if (!_isEnabled || batches.isEmpty) {
      return;
    }

    for (final batch in batches) {
      batch.isUploadPending = true;
    }

    final uploadBatch = UploadBatch(
      batches: batches,
      uploadId: _generateUploadId(),
      createdAt: DateTime.now(),
    );

    _uploadQueue.add(uploadBatch);

    if (_uploadQueue.length >= 3) {
      _tryUpload();
    }
  }

  @Deprecated('Use queueBatchesForUpload instead')
  bool addGroupedDataForUpload(
      Map<GeolocationData, Map<String, List<double>>> groupedData,
      List<GeolocationData> gpsBuffer) {
    if (!_isEnabled) {
      return false;
    }

    final batches = <SensorBatch>[];
    for (final entry in groupedData.entries) {
      batches.add(SensorBatch(
        geoLocation: entry.key,
        aggregatedData: entry.value,
        timestamp: DateTime.now(),
      ));
    }

    queueBatchesForUpload(batches);
    return true;
  }

  Future<void> uploadRemainingBufferedData() async {
    if (_uploadQueue.isNotEmpty) {
      try {
        await _uploadAllQueued();
        _uploadQueue.clear();
      } catch (e, st) {
        final isNonCriticalError = e is TooManyRequestsException ||
            e.toString().contains('Server error') ||
            e.toString().contains('Token refreshed') ||
            e is TimeoutException;

        if (!isNonCriticalError) {
          ErrorService.handleError(
              'Upload failed during recording stop: $e', st,
              sendToSentry: true);
          _uploadQueue.clear();
        }
      }
    }
  }

  Future<void> _tryUpload() async {
    if (_uploadQueue.isEmpty || _isUploading) {
      return;
    }

    if (_isPermanentlyDisabled) {
      return;
    }

    if (!openSenseMapService.isAcceptingRequests) {
      return;
    }

    _isUploading = true;

    try {
      final uploadBatch = _uploadQueue.first;
      uploadBatch.recordAttempt();

      final data = _prepareUploadData(uploadBatch.batches);

      if (data.isEmpty) {
        _uploadQueue.removeAt(0);
        return;
      }

      await openSenseMapBloc.uploadData(senseBox.id, data);

      _uploadQueue.removeAt(0);

      final geoIds = uploadBatch.geoLocationIds;
      _onUploadSuccess?.call(geoIds);
    } catch (e, st) {
      final isNonCriticalError = e is TooManyRequestsException ||
          e.toString().contains('Server error') ||
          e.toString().contains('Token refreshed') ||
          e is TimeoutException;

      if (!isNonCriticalError) {
        ErrorService.handleError(
            'Direct upload failed: $e', st,
            sendToSentry: true);
        await _handleUploadError(e, st);
      } else {
        final batch = _uploadQueue.first;
        for (final b in batch.batches) {
          b.isUploadPending = false;
        }

        if (batch.hasExceededMaxRetries()) {
          debugPrint(
              '[DirectUploadService] Upload batch exceeded max retries, removing');
          _uploadQueue.removeAt(0);
        }
      }
    } finally {
      _isUploading = false;
    }
  }

  Future<void> _uploadAllQueued() async {
    if (_uploadQueue.isEmpty) return;

    if (_isPermanentlyDisabled) {
      return;
    }

    if (_isUploading) return;
    _isUploading = true;

    try {
      final allBatches = <SensorBatch>[];
      for (final uploadBatch in _uploadQueue) {
        allBatches.addAll(uploadBatch.batches);
      }

      final data = _prepareUploadData(allBatches);

      if (data.isEmpty) return;

      await openSenseMapBloc.uploadData(senseBox.id, data);

      _uploadQueue.clear();
      
    } catch (e, st) {
      ErrorService.handleError(
          'Batch upload failed: $e', st,
          sendToSentry: true);
      await _handleUploadError(e, st);
      rethrow;
    } finally {
      _isUploading = false;
    }
  }

  Map<String, dynamic> _prepareUploadData(List<SensorBatch> batches) {
    final allData = <GeolocationData, Map<String, List<double>>>{};

    for (final batch in batches) {
      allData[batch.geoLocation] = batch.aggregatedData;
    }

    return _dataPreparer.prepareDataFromGroupedData(
      allData,
      allData.keys.toList(),
    );
  }

  String _generateUploadId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_uploadQueue.length}';
  }

  void _clearAllBuffers() {
    _uploadQueue.clear();
  }

  Future<void> _handleUploadError(dynamic e, StackTrace st) async {
    final errorString = e.toString();

    if (errorString.contains('Token refreshed')) {
      return;
    }

    if (errorString.contains('Not authenticated') ||
        errorString.contains('Authentication failed') ||
        errorString.contains('No refresh token found') ||
        errorString.contains('Refresh token is expired')) {
      ErrorService.handleError(
          'Authentication error: $e',
          st,
          sendToSentry: false);
      return;
    }
    
    if (errorString.contains('Client error') && !errorString.contains('429')) {
      await _handlePermanentClientError(e, st);
    } else {
      ErrorService.handleError(
          'Temporary upload error: $e',
          st,
          sendToSentry: false);
    }
  }

  Future<void> _handlePermanentClientError(dynamic e, StackTrace st) async {
    ErrorService.handleError(
        'Permanent client error: $e',
        st,
        sendToSentry: true);
    
    _isEnabled = false;
    _isPermanentlyDisabled = true;
    _isUploadDisabled = true;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _clearAllBuffers();
    permanentUploadLossNotifier.value = true;
    _onPermanentDisable?.call();
  }

  void _startPeriodicUploadCheck() {
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(Duration(seconds: 10), (_) async {
      if (_isPermanentlyDisabled) {
        return;
      }
      
      if (_uploadQueue.isNotEmpty && openSenseMapService.isAcceptingRequests) {
        _tryUpload().catchError((e) {
          // Errors handled in _tryUpload
        });
      }
    });
  }

  void dispose() {
    _isUploading = false;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _uploadQueue.clear();
  }
} 