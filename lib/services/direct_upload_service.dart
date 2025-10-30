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
  bool _isUploading = false;

  DirectUploadService({
    required this.openSenseMapService,
    required this.senseBox,
    required this.openSenseMapBloc,
  }) : _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  void enable() {
    _isEnabled = true;
    _clearAllBuffers();
    debugPrint('[DirectUploadService] Service enabled');
  }

  void disable() {
    _isEnabled = false;
    _clearAllBuffers();
    permanentUploadLossNotifier.value = true;
    _onPermanentDisable?.call();
  }

  bool get isEnabled => _isEnabled;
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

    if (openSenseMapService.isAcceptingRequests && !_isUploading) {
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
      } catch (e) {
        _uploadQueue.clear();
      }
    }
  }

  Future<void> _tryUpload() async {
    if (!_isEnabled || _uploadQueue.isEmpty || _isUploading) {
      return;
    }

    if (!openSenseMapService.isAcceptingRequests) {
      return;
    }

    _isUploading = true;

    try {
      final uploadBatch = _uploadQueue.first;

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
      final errorString = e.toString();
      
      if (e is TooManyRequestsException) {
        return;
      }
      
      if (errorString.contains('Server error')) {
        return;
      }

      if (errorString.contains('Token refreshed')) {
        return;
      }

      if (errorString.contains('Not authenticated') ||
          errorString.contains('Authentication failed') ||
          errorString.contains('No refresh token found') ||
          errorString.contains('Refresh token is expired')) {
        ErrorService.handleError('Authentication error: $e', st,
            sendToSentry: false);
        _uploadQueue.removeAt(0);
        _handlePermanentAuthFailure();
        return;
      }
      
      ErrorService.handleError('Upload failed: $e', st, sendToSentry: true);
      final failedBatch = _uploadQueue.removeAt(0);

      for (final b in failedBatch.batches) {
        b.isUploadPending = false;
      }
    } finally {
      _isUploading = false;
    }
  }

  Future<void> _uploadAllQueued() async {
    if (!_isEnabled || _uploadQueue.isEmpty || _isUploading) {
      return;
    }
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
      ErrorService.handleError('Batch upload failed: $e', st,
          sendToSentry: true);
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

  void _handlePermanentAuthFailure() {
    _isEnabled = false;
    _clearAllBuffers();
    permanentUploadLossNotifier.value = true;
    _onPermanentDisable?.call();
  }

  void dispose() {
    _isUploading = false;
    _uploadQueue.clear();
  }
} 