import 'dart:async';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
import 'package:sensebox_bike/models/timestamped_sensor_value.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';

abstract class Sensor {
  final String characteristicUuid;
  final String title;
  final List<String> attributes;
  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final IsarService isarService;

  final StreamController<List<double>> _valueController =
      StreamController<List<double>>.broadcast();
  final StreamController<TimestampedSensorValue> _timestampedValueController =
      StreamController<TimestampedSensorValue>.broadcast();
  StreamSubscription<List<double>>? _subscription;
  StreamSubscription<GeolocationData>? _geoSubscription;
  StreamSubscription<List<int>>? _uploadSuccessSubscription;
  
  final Map<int, SensorBatch> _sensorBatches = {};
  final List<TimestampedSensorValue> _preGpsValues = [];
  
  DirectUploadService? _directUploadService;
  VoidCallback? _recordingListener;
  bool _isFlushing = false;
  bool _isListening = false;
  bool _isStartingListening = false;
  int _subscriptionId = 0;
  
  // Track pending aggregations (geolocations waiting for lookback window to close)
  // Key: geoId, Value: Completer that can be used to cancel the future
  final Map<int, Completer<void>> _pendingAggregations = {};
  
  // Track pending geolocation data for event-driven re-aggregation
  // Key: geoId, Value: GeolocationData with timestamp for window checking
  final Map<int, GeolocationData> _pendingGeolocations = {};

  /// Lookback window duration for retroactive aggregation
  /// All sensors must override this to provide a non-zero lookback window
  Duration get lookbackWindow => Duration.zero;

  /// Maximum age of values to keep in buffer (for cleanup)
  /// Values older than this will be removed
  Duration get maxBufferAge => const Duration(seconds: 5);

  Sensor(
    this.characteristicUuid,
    this.title,
    this.attributes,
    this.bleBloc,
    this.geolocationBloc,
    this.recordingBloc,
    this.isarService,
  );

  Stream<List<double>> get valueStream => _valueController.stream;
  
  /// Stream that emits sensor values with their timestamps (used for aggregation)
  /// This stream uses the same timestamp that's used for aggregation window calculation
  Stream<TimestampedSensorValue> get timestampedValueStream =>
      _timestampedValueController.stream;

  List<double> aggregateData(List<List<double>> rawData);

  int get uiPriority;

  void setDirectUploadService(DirectUploadService uploadService) {
    _directUploadService = uploadService;
    
    _uploadSuccessSubscription?.cancel();
    _uploadSuccessSubscription =
        uploadService.uploadSuccessStream.listen((uploadedGeoIds) {
      for (final geoId in uploadedGeoIds) {
        final batch = _sensorBatches[geoId];
        if (batch != null) {
          batch.isUploaded = true;
          batch.isUploadPending = false;
          _sensorBatches.remove(geoId);
        }
      }
    });
  }

  void onDataReceived(List<double> data) {
    if (data.isNotEmpty && recordingBloc.isRecording) {
      final sensorTimestamp = DateTime.now().toUtc();
      final timestampedValue = TimestampedSensorValue(
        values: data,
        timestamp: sensorTimestamp,
      );
      _preGpsValues.add(timestampedValue);

      _checkAndTriggerPendingAggregations(sensorTimestamp);
      _cleanupOldValues();
      _timestampedValueController.add(timestampedValue);
    }
    
    _valueController.add(data);
  }

  /// Removes values older than maxBufferAge from the buffer
  void _cleanupOldValues() {
    final now = DateTime.now();
    final cutoffTime = now.subtract(maxBufferAge);
    _preGpsValues.removeWhere((entry) => entry.timestamp.isBefore(cutoffTime));
  }

  void _checkAndTriggerPendingAggregations(DateTime sensorTimestamp) {
    if (_pendingGeolocations.isEmpty) return;

    final now = DateTime.now().toUtc();
    final geoIdsToProcess = <int>[];

    for (final entry in _pendingGeolocations.entries) {
      final geoId = entry.key;
      final geo = entry.value;
      final geoTimeUtc = _toUtc(geo.timestamp);
      
      final batch = _sensorBatches[geoId];
      final geoArrivalTime = batch?.timestamp ?? geo.timestamp;
      final waitUntilTime = geoArrivalTime.add(lookbackWindow);

      final sensorTimestampUtc = _toUtc(sensorTimestamp);
      if (sensorTimestampUtc.isAfter(geoTimeUtc) ||
          !now.isBefore(waitUntilTime)) {
        geoIdsToProcess.add(geoId);
      }
    }

    for (final geoId in geoIdsToProcess) {
      final geo = _pendingGeolocations[geoId];
      if (geo != null) {
        _cancelPendingAggregation(geoId);
        _performDeferredAggregation(geoId, geo);
      }
    }
  }

  void _scheduleDeferredAggregation(int geoId, GeolocationData geo) {
    final batch = _sensorBatches[geoId];
    final geoArrivalTime = batch?.timestamp ?? DateTime.now().toUtc();
    final waitUntilTime = geoArrivalTime.add(lookbackWindow);
    final now = DateTime.now().toUtc();
    final delay = waitUntilTime.difference(now);

    final completer = Completer<void>();
    _pendingAggregations[geoId] = completer;

    if (delay.isNegative) {
      Future.microtask(() {
        if (!completer.isCompleted) {
          _performDeferredAggregation(geoId, geo);
          _pendingAggregations.remove(geoId);
          _pendingGeolocations.remove(geoId);
        }
      });
    } else {
      Future.delayed(delay, () {
        if (!completer.isCompleted) {
          _performDeferredAggregation(geoId, geo);
          _pendingAggregations.remove(geoId);
          _pendingGeolocations.remove(geoId);
        }
      });
    }
  }

  /// Cancels a pending aggregation for a specific geolocation
  void _cancelPendingAggregation(int geoId) {
    final completer = _pendingAggregations[geoId];
    if (completer != null && !completer.isCompleted) {
      completer.complete();
      _pendingAggregations.remove(geoId);
    }
    _pendingGeolocations.remove(geoId);
  }

  DateTime _toUtc(DateTime timestamp) {
    return timestamp.isUtc ? timestamp : timestamp.toUtc();
  }

  void _removeAggregatedValues(DateTime geoTime) {
    final geoTimeUtc = _toUtc(geoTime);
    _preGpsValues.removeWhere((entry) {
      final entryTimeUtc = _toUtc(entry.timestamp);
      return entryTimeUtc.isBefore(geoTimeUtc) ||
          entryTimeUtc.isAtSameMomentAs(geoTimeUtc);
    });
  }

  List<List<double>> _getValuesInLookbackWindow(DateTime geoTime) {
    final geoTimeUtc = _toUtc(geoTime);
    
    // Calculate window start: previous geolocation timestamp, or beginning of data for first geolocation
    DateTime windowStart;
    // Check if this is the first geolocation by comparing with existing batches
    // (excluding the current one which might already be in _sensorBatches)
    // Use timestamp comparison with tolerance to handle potential precision differences
    final otherBatches = _sensorBatches.values.where((b) {
      final timeDiff = (b.geoLocation.timestamp.difference(geoTimeUtc)).abs();
      return timeDiff.inMilliseconds >
          100; // Different if more than 100ms apart
    }).toList();

    if (otherBatches.isEmpty) {
      // First geolocation: use all buffered data points (start from beginning)
      // windowStart should be BEFORE geolocation timestamp to allow readings
      // with timestamp <= geoTime to be included
      if (_preGpsValues.isEmpty) {
        windowStart =
            geoTimeUtc.subtract(const Duration(days: 1)); // Fallback if no data
      } else {
        // Use the minimum of earliest sensor reading and geolocation timestamp
        // This ensures windowStart <= windowEnd even if all readings arrive after geoTime
        final earliestReading = _preGpsValues
            .map((e) => e.timestamp)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        // Set windowStart to be before geoTime, using earliest reading if it's before geoTime,
        // otherwise use geoTime - 1 day to ensure valid window
        if (earliestReading.isBefore(geoTimeUtc) ||
            earliestReading.isAtSameMomentAs(geoTimeUtc)) {
          windowStart = earliestReading;
        } else {
          // All readings arrived after geolocation timestamp
          // Set windowStart before geoTime to allow readings with timestamp <= geoTime
          windowStart = geoTimeUtc.subtract(const Duration(days: 1));
        }
      }
    } else {
      // Not first geolocation: window starts at previous geolocation timestamp
      // Find the most recent geolocation
      otherBatches.sort(
          (a, b) => a.geoLocation.timestamp.compareTo(b.geoLocation.timestamp));
      final previousGeo = otherBatches.last.geoLocation;
      final previousGeoTimeUtc = _toUtc(previousGeo.timestamp);
      windowStart = previousGeoTimeUtc.add(const Duration(microseconds: 1));
    }
    final windowEnd = geoTimeUtc;
    final valuesInWindow = _preGpsValues
        .where((entry) =>
            entry.timestamp.isAfter(
                windowStart.subtract(const Duration(microseconds: 1))) &&
            !entry.timestamp.isAfter(windowEnd))
        .map((entry) => entry.values)
        .toList();

    return valuesInWindow;
  }

  void _performDeferredAggregation(int geoId, GeolocationData geo) {
    final batch = _sensorBatches[geoId];
    if (batch == null) {
      return;
    }

    final batchGeo = batch.geoLocation;
    final valuesInWindow = _getValuesInLookbackWindow(batchGeo.timestamp);

    if (valuesInWindow.isNotEmpty) {
      final aggregated = aggregateData(valuesInWindow);

      if (batch.aggregatedData.containsKey(title)) {
        return;
      }

      batch.aggregatedData[title] = aggregated;

      Future.microtask(() async {
        await _flushBuffers();
      });

      _removeAggregatedValues(batchGeo.timestamp);
    }
  }


  Future<void> startListening() async {
    if (_isListening) {
      return;
    }
    if (_isStartingListening) {
      while (_isStartingListening) {
        await Future.delayed(Duration(milliseconds: 10));
      }
    }
    _isStartingListening = true;
    _isListening = true;
    
    try {
      if (_subscription != null) {
        await _subscription?.cancel();
        _subscription = null;
      }
      if (_geoSubscription != null) {
        await _geoSubscription?.cancel();
        _geoSubscription = null;
      }

      if (!_isListening) {
        return;
      }

      final stream = bleBloc.getCharacteristicStream(characteristicUuid);
      _subscriptionId++;
      _subscription = stream.listen((data) {
        onDataReceived(data);
      });
      _geoSubscription = geolocationBloc.geolocationStream.listen((geo) async {
        final geoId = geo.id;
        final isRecording = recordingBloc.isRecording;

        await _flushBuffers();

        // Create batch entry for this geolocation (if it doesn't exist)
        // This ensures the batch exists even if aggregation is deferred
        final isNewBatch = !_sensorBatches.containsKey(geoId);
        _sensorBatches.putIfAbsent(
          geoId,
          () => SensorBatch(
            geoLocation: geo,
            aggregatedData: {},
            timestamp: DateTime.now(),
          ),
        );

        if (!isRecording) {
          // Recording stopped - immediately aggregate and process this geolocation
          _cancelPendingAggregation(geoId);
          _performDeferredAggregation(geoId, geo);
          await _flushBuffers();
        } else {
          // Defer aggregation until lookback window closes
          // This ensures we capture all values that arrive within the window
          _cancelPendingAggregation(geoId);
          _pendingGeolocations[geoId] = geo;
          _scheduleDeferredAggregation(geoId, geo);
        }
      });

      // Remove existing listener if any
      if (_recordingListener != null) {
        recordingBloc.isRecordingNotifier.removeListener(_recordingListener!);
      }
      
      _recordingListener = () {
        if (!recordingBloc.isRecording) {
          _flushBuffers();
        }
      };
      recordingBloc.isRecordingNotifier.addListener(_recordingListener!);
    } catch (e) {
      _isListening = false;
    } finally {
      _isStartingListening = false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }
    
    // Cancel all pending aggregations
    for (final geoId in _pendingAggregations.keys.toList()) {
      _cancelPendingAggregation(geoId);
    }
    _pendingAggregations.clear();
    _pendingGeolocations.clear();
    
    if (_subscription != null) {
      await _subscription?.cancel();
      _subscription = null;
    }
    if (_geoSubscription != null) {
      await _geoSubscription?.cancel();
      _geoSubscription = null;
    }
    await _uploadSuccessSubscription?.cancel();
    _uploadSuccessSubscription = null;
    
    if (_recordingListener != null) {
      recordingBloc.isRecordingNotifier.removeListener(_recordingListener!);
      _recordingListener = null;
    }

    await _flushBuffers();
    _isListening = false;
  }

  Future<void> flushBuffers() async {
    await _flushBuffers();
  }

  void clearBuffersForNewRecording() {
    for (final geoId in _pendingAggregations.keys.toList()) {
      _cancelPendingAggregation(geoId);
    }
    _pendingAggregations.clear();
    _pendingGeolocations.clear();
    _sensorBatches.clear();
    _preGpsValues.clear();
  }

  /// Check if sensor has remaining values that need to be processed when recording stops
  bool hasRemainingValuesWhenStopped() {
    return _preGpsValues.isNotEmpty;
  }

  /// Get SensorData entries for a specific geolocation ID without saving them
  /// Returns empty list if no batch exists for the geolocation or no data is available
  List<SensorData> getSensorDataForGeolocation(int geoId) {
    final batch = _sensorBatches[geoId];
    if (batch == null) {
      return [];
    }

    final sensorData = batch.aggregatedData[title];
    if (sensorData == null || sensorData.isEmpty) {
      return [];
    }

    final List<SensorData> result = [];
    if (attributes.isNotEmpty) {
      for (int j = 0; j < attributes.length && j < sensorData.length; j++) {
        result.add(SensorData()
          ..characteristicUuid = characteristicUuid
          ..title = title
          ..value = sensorData[j]
          ..attribute = attributes[j]
          ..geolocationData.value = batch.geoLocation);
      }
    } else {
      result.add(SensorData()
        ..characteristicUuid = characteristicUuid
        ..title = title
        ..value = sensorData.isNotEmpty ? sensorData[0] : 0.0
        ..attribute = null
        ..geolocationData.value = batch.geoLocation);
    }

    return result;
  }

  /// Mark a batch for a specific geolocation as saved to database
  void markBatchAsSaved(int geoId) {
    final batch = _sensorBatches[geoId];
    if (batch != null) {
      batch.isSavedToDb = true;
    }
  }

  Future<void> _flushBuffers() async {
    final isRecording = recordingBloc.isRecording;

    if (!isRecording && _pendingAggregations.isNotEmpty) {
      final pendingGeoIds = _pendingAggregations.keys.toList();
      for (final geoId in pendingGeoIds) {
        _cancelPendingAggregation(geoId);
        final batch = _sensorBatches[geoId];
        if (batch != null) {
          _performDeferredAggregation(geoId, batch.geoLocation);
        }
      }
    }

    if (_sensorBatches.isEmpty && _preGpsValues.isEmpty) {
      return;
    }

    if (_isFlushing) {
      return;
    }
    _isFlushing = true;

    try {

      final batchesToProcess = _sensorBatches.values
          .where((b) =>
              !b.isUploaded &&
              (!b.isSavedToDb ||
                  (_directUploadService != null &&
                      _directUploadService!.isEnabled)))
          .toList();

      if (batchesToProcess.isEmpty) {
        return;
      }

      final maxBatchSize = 100;
      final batchesToSave = batchesToProcess.take(maxBatchSize).toList();

      final List<SensorData> dbBatch = [];
      final Map<GeolocationData, Map<String, List<double>>> uploadData = {};
      final List<int> geoIdsToSave = [];

      for (final batch in batchesToSave) {
        final geolocation = batch.geoLocation;
        
        if (geolocation.id == Isar.autoIncrement || geolocation.id == 0) {
          continue;
        }

        final sensorData = batch.aggregatedData[title];
        if (sensorData == null || sensorData.isEmpty) {
          continue;
        }

        if (attributes.isNotEmpty) {
          for (int j = 0; j < attributes.length && j < sensorData.length; j++) {
            dbBatch.add(SensorData()
              ..characteristicUuid = characteristicUuid
              ..title = title
              ..value = sensorData[j]
              ..attribute = attributes[j]
              ..geolocationData.value = geolocation);
          }
        } else {
          dbBatch.add(SensorData()
            ..characteristicUuid = characteristicUuid
            ..title = title
            ..value = sensorData.isNotEmpty ? sensorData[0] : 0.0
            ..attribute = null
            ..geolocationData.value = geolocation);
        }

        if (_directUploadService != null && _directUploadService!.isEnabled) {
          uploadData[geolocation] = {title: sensorData};
        }

        geoIdsToSave.add(geolocation.id);
      }

      if (dbBatch.isNotEmpty) {
        try {
          await isarService.sensorService.saveSensorDataBatch(dbBatch);
          
          for (final geoId in geoIdsToSave) {
            final batch = _sensorBatches[geoId];
            if (batch != null) {
              batch.isSavedToDb = true;
            }
          }
        } catch (e) {
          return;
        }
      }

      final canUpload = _directUploadService != null &&
          uploadData.isNotEmpty &&
          _directUploadService!.isEnabled;

      if (canUpload) {
        final batchRefs = geoIdsToSave
            .map((id) => _sensorBatches[id])
            .where((b) => b != null && !b.isUploaded)
            .cast<SensorBatch>()
            .toList();
        
        for (final batch in batchRefs) {
          if (batch.isUploadPending) {
            batch.isUploadPending = false;
          }
        }

        if (batchRefs.isNotEmpty) {
          _directUploadService!.queueBatchesForUpload(batchRefs);
        }
      }
    } finally {
      _isFlushing = false;
    }
  }

  Widget buildWidget();
  
  void dispose() {
    stopListening();
    _valueController.close();
  }
}
