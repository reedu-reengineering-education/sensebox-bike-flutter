import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
import 'package:sensebox_bike/models/upload_batch.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/upload_error_classifier.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';

class DirectUploadService {
  final OpenSenseMapService openSenseMapService;
  final SenseBox senseBox;
  final OpenSenseMapBloc openSenseMapBloc;
  final VoidCallback? onDataLoss;
  final UploadDataPreparer _dataPreparer;
  
  final StreamController<List<int>> _uploadSuccessController =
      StreamController<List<int>>.broadcast();
  
  final List<UploadBatch> _uploadQueue = [];
  
  bool _isEnabled = false;
  bool _isUploading = false;
  bool _dataLossReported = false;
  
  static const int maxQueueSize = 1000;

  DirectUploadService({
    required this.openSenseMapService,
    required this.senseBox,
    required this.openSenseMapBloc,
    this.onDataLoss,
  }) : _dataPreparer = UploadDataPreparer(senseBox: senseBox);

  Stream<List<int>> get uploadSuccessStream => _uploadSuccessController.stream;

  void enable() {
    _isEnabled = true;
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
      _uploadQueue.add(_createUploadBatch(batchesToAdd));
    }

    if (openSenseMapService.isAcceptingRequests && !_isUploading) {
      _tryUpload();
    }
  }

  void _markBatchesAsPending(List<SensorBatch> batches) {
    for (final batch in batches) {
      if (!batch.isUploaded) {
        batch.isUploadPending = true;
      }
    }
  }

  List<SensorBatch> _mergeBatchesIntoQueue(List<SensorBatch> newBatches) {
    final batchesToAdd = <SensorBatch>[];
    
    for (final newBatch in newBatches) {
      bool merged = false;

      if (!_isUploading) {
        merged = _tryMergeBatchIntoQueue(newBatch);
      }

      if (!merged) {
        batchesToAdd.add(newBatch);
      }
    }
    
    return batchesToAdd;
  }

  bool _tryMergeBatchIntoQueue(SensorBatch newBatch) {
    for (final uploadBatch in _uploadQueue) {
      final existingBatchIndex = uploadBatch.batches.indexWhere(
        (b) => b.geoLocation.id == newBatch.geoLocation.id,
      );

      if (existingBatchIndex >= 0) {
        final existingBatch = uploadBatch.batches[existingBatchIndex];
        existingBatch.aggregatedData.addAll(newBatch.aggregatedData);
        return true;
      }
    }
    return false;
  }

  void _enforceQueueLimit(int batchesToAdd) {
    final currentTotal = _totalBatchesInQueue;
    final newTotal = currentTotal + batchesToAdd;
    
    if (newTotal > maxQueueSize) {
      final batchesToRemove = newTotal - maxQueueSize;
      
      int removedCount = 0;
      while (_uploadQueue.isNotEmpty && removedCount < batchesToRemove) {
        final oldestBatch = _uploadQueue.removeAt(0);
        removedCount += oldestBatch.batches.length;
      }
    }
  }

  UploadBatch _createUploadBatch(List<SensorBatch> batches) {
    return UploadBatch(
      batches: batches,
      uploadId: _generateUploadId(),
      createdAt: DateTime.now(),
    );
  }

  Future<void> uploadRemainingBufferedData() async {
    if (_uploadQueue.isNotEmpty) {
      try {
        await _uploadAllQueued();
        _uploadQueue.clear();
      } catch (e, st) {
        _reportDataLoss();
        ErrorService.handleError(
            'Failed to upload remaining buffered data: $e', st);
        _uploadQueue.clear();
      }
    }
  }

  void _reportDataLoss() {
    if (!_dataLossReported) {
      _dataLossReported = true;
      onDataLoss?.call();
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
      final queueSnapshot = List<UploadBatch>.from(_uploadQueue);
      final mergedBatches = _mergeBatchesByGeoId(_collectAllBatches(queueSnapshot));

      final data = _prepareUploadData(mergedBatches);

      if (data.isEmpty) {
        _removeFirstBatch();
        return;
      }

      await openSenseMapBloc.uploadData(senseBox.id, data);

      _handleSuccessfulUpload(queueSnapshot);

      _mergeDuplicateBatchesInQueue();

      if (_uploadQueue.isNotEmpty && !_isUploading) {
        _tryUpload();
      }
    } catch (e, st) {
      _handleUploadError(e, st);
    } finally {
      _isUploading = false;
    }
  }

  List<SensorBatch> _collectAllBatches(List<UploadBatch> uploadBatches) {
    final allBatches = <SensorBatch>[];
    for (final uploadBatch in uploadBatches) {
      allBatches.addAll(uploadBatch.batches);
    }
    return allBatches;
  }

  List<SensorBatch> _mergeBatchesByGeoId(List<SensorBatch> batches) {
    final mergedBatches = <int, SensorBatch>{};

    for (final batch in batches) {
      final geoId = batch.geoLocation.id;
      if (mergedBatches.containsKey(geoId)) {
        final existingBatch = mergedBatches[geoId]!;
        existingBatch.aggregatedData.addAll(batch.aggregatedData);
      } else {
        final mergedBatch = SensorBatch(
          geoLocation: batch.geoLocation,
          aggregatedData: Map<String, List<double>>.from(batch.aggregatedData),
          timestamp: batch.timestamp,
        );
        mergedBatch.isUploadPending = batch.isUploadPending;
        mergedBatches[geoId] = mergedBatch;
      }
    }

    return mergedBatches.values.toList();
  }

  void _handleSuccessfulUpload(List<UploadBatch> queueSnapshot) {
    final uploadedGeoIds = <int>[];
    
    for (final uploadBatch in queueSnapshot) {
      for (final batch in uploadBatch.batches) {
        batch.isUploadPending = false;
        uploadedGeoIds.add(batch.geoLocation.id);
      }
      _uploadQueue.remove(uploadBatch);
    }

    _uploadSuccessController.add(uploadedGeoIds.toSet().toList());
  }

  void _handleUploadError(dynamic error, StackTrace stackTrace) {
    final errorType = UploadErrorClassifier.classifyError(error);
    
    switch (errorType) {
      case UploadErrorType.temporary:
        // Don't report data loss for temporary errors - upload may succeed on next attempt
        return;
        
      case UploadErrorType.permanentAuth:
        _reportDataLoss();
        ErrorService.handleError('Authentication error: $error', stackTrace,
            sendToSentry: false);
        _removeFirstBatch();
        return;
        
      case UploadErrorType.permanentClient:
        _reportDataLoss();
        ErrorService.handleError('Client error: $error', stackTrace,
            sendToSentry: true);
        _removeFirstBatch();
        disable();
        return;
    }
  }

  Future<void> _uploadAllQueued() async {
    final isFinalFlush = !_isEnabled;

    if ((!_isEnabled && !isFinalFlush) ||
        _uploadQueue.isEmpty ||
        _isUploading) {
      return;
    }
    
    if (isFinalFlush) {
      _isEnabled = true;
    }
    
    _isUploading = true;

    try {
      final allBatches = _collectAllBatches(_uploadQueue);
      final data = _prepareUploadData(allBatches);

      if (data.isEmpty) {
        _uploadQueue.clear();
        return;
      }

      await openSenseMapBloc.uploadData(senseBox.id, data);
      _uploadQueue.clear();
      
    } catch (e, st) {
      ErrorService.handleError('Batch upload failed: $e', st,
          sendToSentry: true);
      _uploadQueue.clear();
      rethrow;
    } finally {
      _isUploading = false;
      if (isFinalFlush) {
        _isEnabled = false;
      }
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

  void _mergeDuplicateBatchesInQueue() {
    if (_uploadQueue.isEmpty) {
      return;
    }

    final allBatches = _collectAllBatches(_uploadQueue);
    final mergedBatches = _mergeBatchesByGeoIdWithMetadata(allBatches);

    _uploadQueue.clear();

    if (mergedBatches.isNotEmpty) {
      _uploadQueue.add(_createUploadBatch(mergedBatches));
    }
  }

  List<SensorBatch> _mergeBatchesByGeoIdWithMetadata(List<SensorBatch> batches) {
    final mergedBatches = <int, SensorBatch>{};
    
    for (final batch in batches) {
      final geoId = batch.geoLocation.id;
      if (mergedBatches.containsKey(geoId)) {
        final existingBatch = mergedBatches[geoId]!;
        existingBatch.aggregatedData.addAll(batch.aggregatedData);
        existingBatch.isUploadPending =
            existingBatch.isUploadPending || batch.isUploadPending;
      } else {
        final mergedBatch = SensorBatch(
          geoLocation: batch.geoLocation,
          aggregatedData: Map<String, List<double>>.from(batch.aggregatedData),
          timestamp: batch.timestamp,
        );
        mergedBatch.isUploadPending = batch.isUploadPending;
        mergedBatch.isSavedToDb = batch.isSavedToDb;
        mergedBatch.isUploaded = batch.isUploaded;
        mergedBatches[geoId] = mergedBatch;
      }
    }

    return mergedBatches.values.toList();
  }

  UploadBatch _removeFirstBatch() {
    final batch = _uploadQueue.removeAt(0);
    for (final b in batch.batches) {
      b.isUploadPending = false;
    }
    return batch;
  }


  void dispose() {
    _isUploading = false;
    _uploadQueue.clear();
    _uploadSuccessController.close();
  }
} 