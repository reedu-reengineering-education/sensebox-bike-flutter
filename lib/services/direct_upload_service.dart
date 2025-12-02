import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
import 'package:sensebox_bike/models/upload_batch.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';

class DirectUploadService {
  final OpenSenseMapService openSenseMapService;
  final SenseBox senseBox;
  final OpenSenseMapBloc openSenseMapBloc;
  final VoidCallback? onUploadFailed;
  final UploadDataPreparer _dataPreparer;
  
  final StreamController<List<int>> _uploadSuccessController =
      StreamController<List<int>>.broadcast();
  
  final List<UploadBatch> _uploadQueue = [];
  
  bool _isEnabled = false;
  bool _isUploading = false;
  bool _uploadFailureReported = false;
  
  static const int maxQueueSize = 1000;

  DirectUploadService({
    required this.openSenseMapService,
    required this.senseBox,
    required this.openSenseMapBloc,
    this.onUploadFailed,
  }) : _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  Stream<List<int>> get uploadSuccessStream => _uploadSuccessController.stream;

  void enable() {
    _isEnabled = true;
    _uploadFailureReported = false;
    _clearAllBuffers();
  }

  void disable() {
    _isEnabled = false;
    _clearAllBuffers();
  }

  bool get isEnabled => _isEnabled;
  bool get hasPreservedData => _uploadQueue.isNotEmpty;
  
  int get _totalBatchesInQueue {
    return _uploadQueue.fold(0, (sum, ub) => sum + ub.batches.length);
  }

  void queueBatchesForUpload(List<SensorBatch> batches) {
    if (!_isEnabled || batches.isEmpty) {
      return;
    }
    
    _markBatchesAsPending(batches);
    final batchesToAdd = _mergeBatchesIntoQueue(batches);

    if (batchesToAdd.isNotEmpty) {
      _enforceQueueLimit(batchesToAdd.length);
      _uploadQueue.add(UploadBatch(
        batches: batchesToAdd,
        uploadId:
            '${DateTime.now().millisecondsSinceEpoch}_${_uploadQueue.length}',
        createdAt: DateTime.now(),
      ));
    }

    if (_canStartUpload()) {
      _tryUpload();
    }
  }

  bool _canStartUpload() {
    return openSenseMapService.isAcceptingRequests &&
        !_isUploading &&
        _isEnabled &&
        _uploadQueue.isNotEmpty;
  }

  void _markBatchesAsPending(List<SensorBatch> batches) {
    batches
        .where((b) => !b.isUploaded)
        .forEach((b) => b.isUploadPending = true);
  }

  List<SensorBatch> _mergeBatchesIntoQueue(List<SensorBatch> newBatches) {
    return _isUploading
        ? newBatches
        : newBatches
            .where((newBatch) => !_tryMergeBatchIntoQueue(newBatch))
            .toList();
  }

  bool _tryMergeBatchIntoQueue(SensorBatch newBatch) {
    for (final uploadBatch in _uploadQueue) {
      final existingBatchIndex = uploadBatch.batches.indexWhere(
        (b) => b.geoLocation.id == newBatch.geoLocation.id,
      );

      if (existingBatchIndex >= 0) {
        uploadBatch.batches[existingBatchIndex].aggregatedData
            .addAll(newBatch.aggregatedData);
        return true;
      }
    }
    return false;
  }

  void _enforceQueueLimit(int batchesToAdd) {
    final newTotal = _totalBatchesInQueue + batchesToAdd;
    
    if (newTotal > maxQueueSize) {
      _removeOldestBatches(newTotal - maxQueueSize);
    }
  }

  void _removeOldestBatches(int batchesToRemove) {
    int removedCount = 0;
    while (_uploadQueue.isNotEmpty && removedCount < batchesToRemove) {
      final oldestBatch = _uploadQueue.removeAt(0);
      removedCount += oldestBatch.batches.length;
    }
  }

  Future<void> uploadRemainingBufferedData() async {
    if (_uploadQueue.isEmpty) {
      return;
    }
    
    try {
      await _uploadAllQueued();
    } catch (e) {
      _isEnabled = false;
      _reportUploadFailure();
    } finally {
      _uploadQueue.clear();
    }
  }

  void _reportUploadFailure() {
    if (!_uploadFailureReported) {
      _uploadFailureReported = true;
      onUploadFailed?.call();
    }
  }

  Future<void> _tryUpload() async {
    if (!_canStartUpload()) {
      return;
    }

    _isUploading = true;

    try {
      final queueSnapshot = List<UploadBatch>.from(_uploadQueue);
      final uploadData = _dataPreparer.prepareDataFromBatches(
        _mergeBatches(
          queueSnapshot.expand((batch) => batch.batches).toList(),
          preserveMetadata: false,
        ),
      );

      if (uploadData.isEmpty) {
        _removeFirstBatch();
        return;
      }

      await openSenseMapBloc.uploadData(senseBox.id, uploadData);
      _handleSuccessfulUpload(queueSnapshot);
      _mergeDuplicateBatchesInQueue();
      if (_canStartUpload()) {
        _tryUpload();
      }
    } catch (_) {
      _handleUploadError();
    } finally {
      _isUploading = false;
    }
  }

  List<SensorBatch> _mergeBatchesByGeoIdWithMetadata(
      List<SensorBatch> batches) {
    return _mergeBatches(batches, preserveMetadata: true);
  }

  List<SensorBatch> _mergeBatches(
    List<SensorBatch> batches, {
    required bool preserveMetadata,
  }) {
    final mergedBatches = <int, SensorBatch>{};

    for (final batch in batches) {
      final geoId = batch.geoLocation.id;
      final existingBatch = mergedBatches[geoId];

      if (existingBatch != null) {
        existingBatch.aggregatedData.addAll(batch.aggregatedData);
        if (preserveMetadata) {
          existingBatch.isUploadPending =
              existingBatch.isUploadPending || batch.isUploadPending;
        }
      } else {
        mergedBatches[geoId] = _createMergedBatch(batch, preserveMetadata);
      }
    }

    return mergedBatches.values.toList();
  }

  SensorBatch _createMergedBatch(SensorBatch batch, bool preserveMetadata) {
    final mergedBatch = SensorBatch(
      geoLocation: batch.geoLocation,
      aggregatedData: Map<String, List<double>>.from(batch.aggregatedData),
      timestamp: batch.timestamp,
    );
    
    if (preserveMetadata) {
      mergedBatch.isUploadPending = batch.isUploadPending;
      mergedBatch.isSavedToDb = batch.isSavedToDb;
      mergedBatch.isUploaded = batch.isUploaded;
    }
    
    return mergedBatch;
  }

  void _handleSuccessfulUpload(List<UploadBatch> queueSnapshot) {
    final uploadedGeoIds = queueSnapshot
        .expand((uploadBatch) => uploadBatch.batches)
        .map((batch) {
          batch.isUploadPending = false;
          return batch.geoLocation.id;
        })
        .toSet()
        .toList();

    _uploadQueue.removeWhere((batch) => queueSnapshot.contains(batch));

    _uploadSuccessController.add(uploadedGeoIds);
  }

  void _handleUploadError() {
    if (!_isEnabled) {
      return;
    }
    
    _isEnabled = false;
    _reportUploadFailure();
    _clearAllBuffers();
  }

  Future<void> _uploadAllQueued() async {
    if (_uploadQueue.isEmpty || _isUploading) {
      return;
    }
    
    _isUploading = true;

    try {
      final allBatches = _uploadQueue.expand((batch) => batch.batches).toList();
      final data = _dataPreparer.prepareDataFromBatches(allBatches);

      if (data.isEmpty) {
        return;
      }

      await openSenseMapBloc.uploadData(senseBox.id, data);
    } finally {
      _isUploading = false;
    }
  }

  void _clearAllBuffers() {
    _uploadQueue.clear();
  }

  void _mergeDuplicateBatchesInQueue() {
    if (_uploadQueue.isEmpty) return;

    final mergedBatches = _mergeBatchesByGeoIdWithMetadata(
      _uploadQueue.expand((batch) => batch.batches).toList(),
    );

    _uploadQueue
      ..clear()
      ..addAll(mergedBatches.isEmpty
          ? []
          : [
              UploadBatch(
                batches: mergedBatches,
                uploadId:
                    '${DateTime.now().millisecondsSinceEpoch}_${_uploadQueue.length}',
                createdAt: DateTime.now(),
              )
            ]);
  }

  UploadBatch _removeFirstBatch() {
    final batch = _uploadQueue.removeAt(0);
    batch.batches.forEach((b) => b.isUploadPending = false);
    return batch;
  }

  void dispose() {
    _isUploading = false;
    _uploadQueue.clear();
    _uploadSuccessController.close();
  }
}
