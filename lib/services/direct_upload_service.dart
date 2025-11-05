import 'dart:async';
import 'package:flutter/widgets.dart';
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
  final UploadDataPreparer _dataPreparer;
  
  final StreamController<List<int>> _uploadSuccessController =
      StreamController<List<int>>.broadcast();
  
  final List<UploadBatch> _uploadQueue = [];
  
  bool _isEnabled = false;
  bool _isUploading = false;
  
  /// Maximum number of SensorBatch objects allowed in the queue
  /// This prevents unbounded memory growth during API outages
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
    debugPrint('[DirectUploadService] Service enabled');
  }

  void disable() {
    _isEnabled = false;
    _clearAllBuffers();
  }

  bool get isEnabled => _isEnabled;
  bool get hasPreservedData => _uploadQueue.isNotEmpty;
  
  /// Get total number of SensorBatch objects in the queue
  int get _totalBatchesInQueue {
    return _uploadQueue.fold(0, (sum, ub) => sum + ub.batches.length);
  }

  void queueBatchesForUpload(List<SensorBatch> batches) {
    if (!_isEnabled || batches.isEmpty) {
      if (!_isEnabled) {
        debugPrint(
            '[DirectUploadService] queueBatchesForUpload: Service disabled, rejecting ${batches.length} batches');
      }
      return;
    }

    final geoIds = batches.map((b) => b.geoLocation.id).toList();
    final sensorTitles = batches.expand((b) => b.sensorTitles).toSet().toList();
    debugPrint(
        '[DirectUploadService] queueBatchesForUpload: INPUT - ${batches.length} batches, geoIds: $geoIds, sensors: $sensorTitles');
    
    for (final batch in batches) {
      batch.isUploadPending = true;
      debugPrint(
          '[DirectUploadService] queueBatchesForUpload: Batch geoId=${batch.geoLocation.id}, sensors=${batch.sensorTitles}, dataPoints=${batch.totalDataPoints}');
    }

    // Merge batches by geoId - find existing batches in queue and merge sensor data
    // IMPORTANT: If upload is in progress, don't merge into existing batches to avoid
    // losing data that arrives during upload (those batches are already being processed)
    final batchesToAdd = <SensorBatch>[];
    for (final newBatch in batches) {
      bool merged = false;

      // Only merge if upload is NOT in progress (to avoid merging into batches being uploaded)
      if (!_isUploading) {
        // Search through all UploadBatches in queue for existing batch with same geoId
        for (final uploadBatch in _uploadQueue) {
          final existingBatchIndex = uploadBatch.batches.indexWhere(
            (b) => b.geoLocation.id == newBatch.geoLocation.id,
          );

          if (existingBatchIndex >= 0) {
            // Merge sensor data into existing batch
            final existingBatch = uploadBatch.batches[existingBatchIndex];
            existingBatch.aggregatedData.addAll(newBatch.aggregatedData);
            debugPrint(
                '[DirectUploadService] queueBatchesForUpload: MERGED ${newBatch.sensorTitles} into existing batch for geoId ${newBatch.geoLocation.id} (existing sensors: ${existingBatch.sensorTitles})');
            merged = true;
            break;
          }
        }
      } else {
        debugPrint(
            '[DirectUploadService] queueBatchesForUpload: Upload in progress, skipping merge for geoId ${newBatch.geoLocation.id} to avoid data loss');
      }

      if (!merged) {
        // No existing batch found, or upload in progress - need to add this one
        batchesToAdd.add(newBatch);
        debugPrint(
            '[DirectUploadService] queueBatchesForUpload: No existing batch for geoId ${newBatch.geoLocation.id}, will add new batch');
      }
    }

    // Create new UploadBatch for batches that weren't merged
    if (batchesToAdd.isNotEmpty) {
      final uploadBatch = UploadBatch(
        batches: batchesToAdd,
        uploadId: _generateUploadId(),
        createdAt: DateTime.now(),
      );

      // Check if adding these batches would exceed the queue limit
      final currentTotal = _totalBatchesInQueue;
      final newTotal = currentTotal + batchesToAdd.length;
      
      if (newTotal > maxQueueSize) {
        final batchesToRemove = newTotal - maxQueueSize;
        debugPrint(
            '[DirectUploadService] queueBatchesForUpload: Queue limit ($maxQueueSize) would be exceeded. Current: $currentTotal, Adding: ${batchesToAdd.length}, Need to remove: $batchesToRemove');
        
        // Remove oldest UploadBatches until we have room
        int removedCount = 0;
        while (_uploadQueue.isNotEmpty && removedCount < batchesToRemove) {
          final oldestBatch = _uploadQueue.removeAt(0);
          removedCount += oldestBatch.batches.length;
          debugPrint(
              '[DirectUploadService] queueBatchesForUpload: Removed oldest UploadBatch with ${oldestBatch.batches.length} batches (geoIds: ${oldestBatch.geoLocationIds})');
        }
        
        debugPrint(
            '[DirectUploadService] queueBatchesForUpload: Removed $removedCount batches to make room. New queue size: ${_totalBatchesInQueue}');
      }

      _uploadQueue.add(uploadBatch);
      debugPrint(
          '[DirectUploadService] queueBatchesForUpload: Added ${batchesToAdd.length} new batches to queue. Queue size: ${_uploadQueue.length}, total batches in queue: ${_totalBatchesInQueue}');
    } else {
      debugPrint(
          '[DirectUploadService] queueBatchesForUpload: All batches merged into existing UploadBatches. Queue size: ${_uploadQueue.length}, total batches in queue: ${_totalBatchesInQueue}');
    }

    if (openSenseMapService.isAcceptingRequests && !_isUploading) {
      debugPrint(
          '[DirectUploadService] queueBatchesForUpload: Service accepting requests, starting upload');
      _tryUpload();
    } else {
      if (!openSenseMapService.isAcceptingRequests) {
        debugPrint(
            '[DirectUploadService] queueBatchesForUpload: Service not accepting requests (rate limited), will upload later');
      }
      if (_isUploading) {
        debugPrint(
            '[DirectUploadService] queueBatchesForUpload: Upload already in progress, will process when current upload completes');
      }
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
      if (!_isEnabled) {
        debugPrint(
            '[DirectUploadService] _tryUpload: Service disabled, skipping');
      } else if (_uploadQueue.isEmpty) {
        debugPrint('[DirectUploadService] _tryUpload: Queue empty, skipping');
      } else if (_isUploading) {
        debugPrint(
            '[DirectUploadService] _tryUpload: Upload already in progress, skipping');
      }
      return;
    }

    if (!openSenseMapService.isAcceptingRequests) {
      debugPrint(
          '[DirectUploadService] _tryUpload: Service not accepting requests, skipping');
      return;
    }

    _isUploading = true;
    final queueSizeBefore = _uploadQueue.length;
    final totalBatchesBefore = _totalBatchesInQueue;

    try {
      // Collect all batches from all UploadBatches and merge by geoId
      // Store a snapshot of the queue to only process what was there when we started
      final queueSnapshot = List<UploadBatch>.from(_uploadQueue);
      final mergedBatches = <int, SensorBatch>{}; // geoId -> merged batch
      final allInputBatches = <SensorBatch>[];

      for (final uploadBatch in queueSnapshot) {
        allInputBatches.addAll(uploadBatch.batches);
      }

      debugPrint(
          '[DirectUploadService] _tryUpload: Collected ${allInputBatches.length} batches from ${queueSnapshot.length} UploadBatches (queue size: ${_uploadQueue.length})');

      // Merge batches by geoId
      for (final batch in allInputBatches) {
        final geoId = batch.geoLocation.id;
        if (mergedBatches.containsKey(geoId)) {
          // Merge sensor data into existing batch
          final existingBatch = mergedBatches[geoId]!;
          existingBatch.aggregatedData.addAll(batch.aggregatedData);
          debugPrint(
              '[DirectUploadService] _tryUpload: Merged batch geoId=$geoId: ${batch.sensorTitles} into existing (merged sensors: ${existingBatch.sensorTitles})');
        } else {
          // Create a copy to avoid modifying the original
          final mergedBatch = SensorBatch(
            geoLocation: batch.geoLocation,
            aggregatedData:
                Map<String, List<double>>.from(batch.aggregatedData),
            timestamp: batch.timestamp,
          );
          mergedBatch.isUploadPending = batch.isUploadPending;
          mergedBatches[geoId] = mergedBatch;
          debugPrint(
              '[DirectUploadService] _tryUpload: Added new batch geoId=$geoId: ${batch.sensorTitles}');
        }
      }

      final mergedBatchesList = mergedBatches.values.toList();
      final inputGeoIds =
          mergedBatchesList.map((b) => b.geoLocation.id).toList();
      debugPrint(
          '[DirectUploadService] _tryUpload: After merging - ${mergedBatchesList.length} unique geoIds: $inputGeoIds');

      for (final batch in mergedBatchesList) {
        debugPrint(
            '[DirectUploadService] _tryUpload: Merged batch geoId=${batch.geoLocation.id}, sensors=${batch.sensorTitles}, dataPoints=${batch.totalDataPoints}, aggregatedData keys: ${batch.aggregatedData.keys.toList()}');
      }

      final data = _prepareUploadData(mergedBatchesList);
      final dataKeys = data.keys.length;
      debugPrint(
          '[DirectUploadService] _tryUpload: Prepared data - keys: $dataKeys');
      debugPrint(
          '[DirectUploadService] _tryUpload: Prepared data keys: ${data.keys.toList()}');

      if (data.isEmpty) {
        debugPrint(
            '[DirectUploadService] _tryUpload: Prepared data is EMPTY, removing batch (geoIds: $inputGeoIds)');
        _removeFirstBatch();
        return;
      }

      debugPrint(
          '[DirectUploadService] _tryUpload: Uploading data with $dataKeys keys for geoIds: $inputGeoIds');
      await openSenseMapBloc.uploadData(senseBox.id, data);
      debugPrint(
          '[DirectUploadService] _tryUpload: Upload SUCCESS for geoIds: $inputGeoIds');

      // Mark all uploaded batches as not pending and remove only the batches we processed
      // (remove the queueSnapshot, not the entire queue, in case new batches arrived during upload)
      final uploadedGeoIds = <int>[];
      for (final uploadBatch in queueSnapshot) {
        for (final batch in uploadBatch.batches) {
          batch.isUploadPending = false;
          uploadedGeoIds.add(batch.geoLocation.id);
        }
        // Remove this UploadBatch from the queue (if it's still there)
        _uploadQueue.remove(uploadBatch);
      }

      debugPrint(
          '[DirectUploadService] _tryUpload: Removed ${queueSnapshot.length} UploadBatches from queue after successful upload (geoIds: ${uploadedGeoIds.toSet().toList()}). Remaining queue size: ${_uploadQueue.length}');
      
      _uploadSuccessController.add(uploadedGeoIds.toSet().toList());

      // Try to upload remaining batches if any were added during upload
      if (_uploadQueue.isNotEmpty && !_isUploading) {
        debugPrint(
            '[DirectUploadService] _tryUpload: More batches in queue (${_uploadQueue.length}), continuing...');
        _tryUpload();
      }
    } catch (e, st) {
      final errorType = UploadErrorClassifier.classifyError(e);
      debugPrint(
          '[DirectUploadService] _tryUpload: ERROR - $e (type: $errorType)');
      
      if (errorType == UploadErrorType.temporary) {
        debugPrint(
            '[DirectUploadService] _tryUpload: Temporary error, keeping batch for retry');
        return;
      }
      
      if (errorType == UploadErrorType.permanentAuth) {
        debugPrint(
            '[DirectUploadService] _tryUpload: Permanent auth error, removing batch and disabling service');
        ErrorService.handleError('Authentication error: $e', st,
            sendToSentry: false);
        final removedBatch = _removeFirstBatch();
        debugPrint(
            '[DirectUploadService] _tryUpload: Removed batch due to auth error (geoIds: ${removedBatch.geoLocationIds})');
        _handlePermanentAuthFailure();
        return;
      }
      
      debugPrint(
          '[DirectUploadService] _tryUpload: Permanent error, removing batch');
      ErrorService.handleError('Upload failed after retries: $e', st,
          sendToSentry: true);
      final removedBatch = _removeFirstBatch();
      debugPrint(
          '[DirectUploadService] _tryUpload: Removed batch due to permanent error (geoIds: ${removedBatch.geoLocationIds})');
    } finally {
      _isUploading = false;
      final queueSizeAfter = _uploadQueue.length;
      final totalBatchesAfter = _totalBatchesInQueue;
      debugPrint(
          '[DirectUploadService] _tryUpload: FINISHED - Queue: $queueSizeBefore -> $queueSizeAfter, Total batches: $totalBatchesBefore -> $totalBatchesAfter');
    }
  }

  Future<void> _uploadAllQueued() async {
    if (!_isEnabled || _uploadQueue.isEmpty || _isUploading) {
      if (!_isEnabled) {
        debugPrint(
            '[DirectUploadService] _uploadAllQueued: Service disabled, skipping');
      } else if (_uploadQueue.isEmpty) {
        debugPrint(
            '[DirectUploadService] _uploadAllQueued: Queue empty, skipping');
      } else if (_isUploading) {
        debugPrint(
            '[DirectUploadService] _uploadAllQueued: Upload already in progress, skipping');
      }
      return;
    }

    final queueSizeBefore = _uploadQueue.length;
    final totalBatchesBefore = _totalBatchesInQueue;
    debugPrint(
        '[DirectUploadService] _uploadAllQueued: Starting - Queue size: $queueSizeBefore, Total batches: $totalBatchesBefore');
    
    _isUploading = true;

    try {
      final allBatches = <SensorBatch>[];
      final allGeoIds = <int>[];
      for (final uploadBatch in _uploadQueue) {
        allBatches.addAll(uploadBatch.batches);
        allGeoIds.addAll(uploadBatch.geoLocationIds);
      }

      debugPrint(
          '[DirectUploadService] _uploadAllQueued: Collected ${allBatches.length} batches from $queueSizeBefore upload batches');
      debugPrint(
          '[DirectUploadService] _uploadAllQueued: All geoIds: $allGeoIds');

      for (final batch in allBatches) {
        debugPrint(
            '[DirectUploadService] _uploadAllQueued: Batch geoId=${batch.geoLocation.id}, sensors=${batch.sensorTitles}, dataPoints=${batch.totalDataPoints}');
      }

      final data = _prepareUploadData(allBatches);
      final dataKeys = data.keys.length;
      debugPrint(
          '[DirectUploadService] _uploadAllQueued: Prepared data - keys: $dataKeys');

      if (data.isEmpty) {
        debugPrint(
            '[DirectUploadService] _uploadAllQueued: Prepared data is EMPTY, clearing queue');
        _uploadQueue.clear();
        return;
      }

      debugPrint(
          '[DirectUploadService] _uploadAllQueued: Uploading data with $dataKeys keys for ${allGeoIds.length} geoIds');
      await openSenseMapBloc.uploadData(senseBox.id, data);
      debugPrint(
          '[DirectUploadService] _uploadAllQueued: Upload SUCCESS for geoIds: $allGeoIds');

      _uploadQueue.clear();
      debugPrint(
          '[DirectUploadService] _uploadAllQueued: Cleared queue after successful upload');
      
    } catch (e, st) {
      debugPrint('[DirectUploadService] _uploadAllQueued: ERROR - $e');
      ErrorService.handleError('Batch upload failed: $e', st,
          sendToSentry: true);
      debugPrint(
          '[DirectUploadService] _uploadAllQueued: Clearing queue after error');
      _uploadQueue.clear();
      rethrow;
    } finally {
      _isUploading = false;
      final queueSizeAfter = _uploadQueue.length;
      debugPrint(
          '[DirectUploadService] _uploadAllQueued: FINISHED - Queue size: $queueSizeBefore -> $queueSizeAfter');
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
    final geoIds = batch.geoLocationIds;
    debugPrint(
        '[DirectUploadService] _removeFirstBatch: Removing UploadBatch with ${batch.batches.length} batches, geoIds: $geoIds');
    for (final b in batch.batches) {
      b.isUploadPending = false;
      debugPrint(
          '[DirectUploadService] _removeFirstBatch: Marked batch geoId=${b.geoLocation.id} as not pending');
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