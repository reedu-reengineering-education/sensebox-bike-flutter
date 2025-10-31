import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
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
  
  final StreamController<List<int>> _uploadSuccessController =
      StreamController<List<int>>.broadcast();
  
  final List<UploadBatch> _uploadQueue = [];
  
  bool _isEnabled = false;
  bool _isUploading = false;

  DirectUploadService({
    required this.openSenseMapService,
    required this.senseBox,
    required this.openSenseMapBloc,
  }) : _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  Stream<List<int>> get uploadSuccessStream => _uploadSuccessController.stream;

  void enable() {
    _isEnabled = true;
    _clearAllBuffers();
    debugPrint('[DirectUploadService] Service enabled');
  }

  void disable() {
    _isEnabled = false;
    _clearAllBuffers();
  }

  bool get isEnabled => _isEnabled;
  bool get hasPreservedData => _uploadQueue.isNotEmpty;

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
        _removeFirstBatch();
        return;
      }

      await openSenseMapBloc.uploadData(senseBox.id, data);

      final removedBatch = _removeFirstBatch();

      final geoIds = removedBatch.geoLocationIds;
      _uploadSuccessController.add(geoIds);
    } catch (e, st) {
      if (e is TooManyRequestsException) {
        return;
      }
      
      if (e
          .toString()
          .contains('Authentication failed - user needs to re-login')) {
        ErrorService.handleError('Authentication error: $e', st,
            sendToSentry: false);
        _removeFirstBatch();
        _handlePermanentAuthFailure();
        return;
      }
      
      ErrorService.handleError('Upload failed after retries: $e', st,
          sendToSentry: true);
      _removeFirstBatch();
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
    return _dataPreparer.prepareDataFromBatches(batches);
  }

  String _generateUploadId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_uploadQueue.length}';
  }

  void _clearAllBuffers() {
    _uploadQueue.clear();
  }

  UploadBatch _removeFirstBatch() {
    final batch = _uploadQueue.removeAt(0);
    for (final b in batch.batches) {
      b.isUploadPending = false;
    }
    return batch;
  }

  void _handlePermanentAuthFailure() {
    disable();
  }

  void dispose() {
    _isUploading = false;
    _uploadQueue.clear();
    _uploadSuccessController.close();
  }
} 