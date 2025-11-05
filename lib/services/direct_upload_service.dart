import 'dart:async';
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
  final UploadDataPreparer _dataPreparer;
  
  final StreamController<List<int>> _uploadSuccessController =
      StreamController<List<int>>.broadcast();
  
  final List<UploadBatch> _uploadQueue = [];
  
  bool _isEnabled = false;
  bool _isUploading = false;
  
  static const int maxQueueSize = 1000;

  DirectUploadService({
    required this.openSenseMapService,
    required this.senseBox,
    required this.openSenseMapBloc,
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
    
    for (final batch in batches) {
      if (!batch.isUploaded) {
        batch.isUploadPending = true;
      }
    }

    final batchesToAdd = <SensorBatch>[];
    for (final newBatch in batches) {
      bool merged = false;

      if (!_isUploading) {
        for (final uploadBatch in _uploadQueue) {
          final existingBatchIndex = uploadBatch.batches.indexWhere(
            (b) => b.geoLocation.id == newBatch.geoLocation.id,
          );

          if (existingBatchIndex >= 0) {
            final existingBatch = uploadBatch.batches[existingBatchIndex];
            existingBatch.aggregatedData.addAll(newBatch.aggregatedData);
            merged = true;
            break;
          }
        }
      }

      if (!merged) {
        batchesToAdd.add(newBatch);
      }
    }

    if (batchesToAdd.isNotEmpty) {
      final uploadBatch = UploadBatch(
        batches: batchesToAdd,
        uploadId: _generateUploadId(),
        createdAt: DateTime.now(),
      );

      final currentTotal = _totalBatchesInQueue;
      final newTotal = currentTotal + batchesToAdd.length;
      
      if (newTotal > maxQueueSize) {
        final batchesToRemove = newTotal - maxQueueSize;
        
        int removedCount = 0;
        while (_uploadQueue.isNotEmpty && removedCount < batchesToRemove) {
          final oldestBatch = _uploadQueue.removeAt(0);
          removedCount += oldestBatch.batches.length;
        }
        
      }

      _uploadQueue.add(uploadBatch);
    }

    if (openSenseMapService.isAcceptingRequests && !_isUploading) {
      _tryUpload();
    }
  }

  Future<void> uploadRemainingBufferedData() async {
    if (_uploadQueue.isNotEmpty) {
      try {
        await _uploadAllQueued();
        _uploadQueue.clear();
      } catch (e, st) {
        ErrorService.handleError(
            'Failed to upload remaining buffered data: $e', st);
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
      final queueSnapshot = List<UploadBatch>.from(_uploadQueue);
      final mergedBatches = <int, SensorBatch>{};
      final allInputBatches = <SensorBatch>[];

      for (final uploadBatch in queueSnapshot) {
        allInputBatches.addAll(uploadBatch.batches);
      }

      for (final batch in allInputBatches) {
        final geoId = batch.geoLocation.id;
        if (mergedBatches.containsKey(geoId)) {
          final existingBatch = mergedBatches[geoId]!;
          existingBatch.aggregatedData.addAll(batch.aggregatedData);
        } else {
          final mergedBatch = SensorBatch(
            geoLocation: batch.geoLocation,
            aggregatedData:
                Map<String, List<double>>.from(batch.aggregatedData),
            timestamp: batch.timestamp,
          );
          mergedBatch.isUploadPending = batch.isUploadPending;
          mergedBatches[geoId] = mergedBatch;
        }
      }

      final mergedBatchesList = mergedBatches.values.toList();

      final data = _prepareUploadData(mergedBatchesList);

      if (data.isEmpty) {
        _removeFirstBatch();
        return;
      }

      await openSenseMapBloc.uploadData(senseBox.id, data);

      final uploadedGeoIds = <int>[];
      for (final uploadBatch in queueSnapshot) {
        for (final batch in uploadBatch.batches) {
          batch.isUploadPending = false;
          uploadedGeoIds.add(batch.geoLocation.id);
        }
        _uploadQueue.remove(uploadBatch);
      }

      _uploadSuccessController.add(uploadedGeoIds.toSet().toList());

      _mergeDuplicateBatchesInQueue();

      if (_uploadQueue.isNotEmpty && !_isUploading) {
        _tryUpload();
      }
    } catch (e, st) {
      final errorType = UploadErrorClassifier.classifyError(e);
      
      if (errorType == UploadErrorType.temporary) {
        return;
      }
      
      if (errorType == UploadErrorType.permanentAuth) {
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
      final allBatches = <SensorBatch>[];
      for (final uploadBatch in _uploadQueue) {
        allBatches.addAll(uploadBatch.batches);
      }

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

    final allBatches = <SensorBatch>[];
    for (final uploadBatch in _uploadQueue) {
      allBatches.addAll(uploadBatch.batches);
    }

    final mergedBatches = <int, SensorBatch>{};
    for (final batch in allBatches) {
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

    final mergedBatchesList = mergedBatches.values.toList();

    _uploadQueue.clear();

    if (mergedBatchesList.isNotEmpty) {
      final consolidatedUploadBatch = UploadBatch(
        batches: mergedBatchesList,
        uploadId: _generateUploadId(),
        createdAt: DateTime.now(),
      );
      _uploadQueue.add(consolidatedUploadBatch);
    }
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