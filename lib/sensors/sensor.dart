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
  
  // Track pending aggregations (geolocations waiting for lookback window to close)
  // Key: geoId, Value: Completer that can be used to cancel the future
  final Map<int, Completer<void>> _pendingAggregations = {};
  
  // Track pending geolocation data for event-driven re-aggregation
  // Key: geoId, Value: GeolocationData with timestamp for window checking
  final Map<int, GeolocationData> _pendingGeolocations = {};

  /// Lookback window duration in milliseconds for retroactive aggregation
  /// Sensors can override this to customize the time window
  /// Default is 0ms (no lookback) for backward compatibility
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
        // Use UTC to match geolocation timestamps which come from GPS device
        timestamp: sensorTimestamp,
      );
      _preGpsValues.add(timestampedValue);

      // Event-driven re-aggregation: Check if this new data falls within
      // any pending geolocation's lookback window and trigger aggregation
      if (lookbackWindow != Duration.zero) {
        _checkAndTriggerPendingAggregations(sensorTimestamp);
      }

      // Clean up old values periodically
      _cleanupOldValues();
      
      // Emit timestamped value for CSV logger
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

  /// Event-driven re-aggregation: Check if new sensor data indicates we should stop waiting
  /// Stop waiting if:
  /// 1. We receive a sensor value with timestamp > geolocation timestamp (doesn't belong to this geo)
  /// 2. 2 seconds have passed since geolocation arrived
  void _checkAndTriggerPendingAggregations(DateTime sensorTimestamp) {
    if (_pendingGeolocations.isEmpty) return;

    final now = DateTime.now().toUtc();
    final geoIdsToProcess = <int>[];

    // Check each pending geolocation
    for (final entry in _pendingGeolocations.entries) {
      final geoId = entry.key;
      final geo = entry.value;
      final geoTimeUtc =
          geo.timestamp.isUtc ? geo.timestamp : geo.timestamp.toUtc();
      
      // Get when this geolocation was added (for 2-second timeout)
      final batch = _sensorBatches[geoId];
      final geoArrivalTime = batch?.timestamp ?? geo.timestamp;
      final waitUntilTime = geoArrivalTime.add(lookbackWindow);

      // Stop waiting if:
      // 1. Sensor timestamp > geolocation timestamp (sensor value doesn't belong to this geo)
      // 2. 2 seconds have passed since geolocation arrived
      final sensorTimestampUtc =
          sensorTimestamp.isUtc ? sensorTimestamp : sensorTimestamp.toUtc();
      if (sensorTimestampUtc.isAfter(geoTimeUtc) ||
          !now.isBefore(waitUntilTime)) {
        geoIdsToProcess.add(geoId);
      }
    }

    // Process geolocations that should stop waiting
    for (final geoId in geoIdsToProcess) {
      final geo = _pendingGeolocations[geoId];
      if (geo != null) {
        _cancelPendingAggregation(geoId);
        _performDeferredAggregation(geoId, geo);
      }
    }
  }

  /// Schedules deferred aggregation using Future.delayed with cancellation support
  /// Waits for 2 seconds OR until a sensor value arrives with timestamp > geolocation timestamp
  void _scheduleDeferredAggregation(int geoId, GeolocationData geo) {
    // Calculate when to stop waiting: 2 seconds after geolocation was added
    final batch = _sensorBatches[geoId];
    final geoArrivalTime = batch?.timestamp ?? DateTime.now().toUtc();
    final waitUntilTime = geoArrivalTime.add(lookbackWindow);
    final now = DateTime.now().toUtc();
    final delay = waitUntilTime.difference(now);

    // Create a completer for cancellation
    final completer = Completer<void>();
    _pendingAggregations[geoId] = completer;

    // Schedule aggregation after 2 seconds
    // If 2 seconds have already passed (negative delay), aggregate immediately
    if (delay.isNegative) {
      // 2 seconds already passed, aggregate immediately
      Future.microtask(() {
        if (!completer.isCompleted) {
          _performDeferredAggregation(geoId, geo);
          _pendingAggregations.remove(geoId);
          _pendingGeolocations.remove(geoId);
        }
      });
    } else {
      // Wait for 2 seconds using Future.delayed
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
      completer.complete(); // Signal cancellation
      _pendingAggregations.remove(geoId);
    }
    _pendingGeolocations.remove(geoId);
  }

  /// Gets all sensor values that belong to a geolocation
  /// Sensor values belong to geolocation if their timestamp <= geolocation timestamp
  /// Window starts at previous geolocation timestamp (or beginning of data for first geolocation)
  /// Window ends at geoTime (inclusive)
  /// Both geoTime and sensor timestamps should be in UTC for correct comparison
  List<List<double>> _getValuesInLookbackWindow(DateTime geoTime) {
    if (lookbackWindow == Duration.zero) {
      // No lookback: return all current values (backward compatible)
      return _preGpsValues.map((entry) => entry.values).toList();
    }

    // Ensure geoTime is in UTC for comparison with sensor timestamps
    final geoTimeUtc = geoTime.isUtc ? geoTime : geoTime.toUtc();
    
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
      final previousGeoTimeUtc = previousGeo.timestamp.isUtc
          ? previousGeo.timestamp
          : previousGeo.timestamp.toUtc();
      // Window starts just after previous geolocation timestamp (exclusive)
      // to avoid double-counting values exactly at the boundary
      windowStart = previousGeoTimeUtc.add(const Duration(microseconds: 1));
    }

    // Window ends at geolocation timestamp (inclusive)
    final windowEnd = geoTimeUtc;

    // Include values where timestamp > windowStart and timestamp <= windowEnd
    final valuesInWindow = _preGpsValues
        .where((entry) =>
            entry.timestamp.isAfter(
                windowStart.subtract(const Duration(microseconds: 1))) &&
            !entry.timestamp.isAfter(windowEnd))
        .map((entry) => entry.values)
        .toList();

    return valuesInWindow;
  }

  /// Performs immediate aggregation (for sensors without lookback window)
  void _performImmediateAggregation(GeolocationData geo) {
    final geoId = geo.id;

    // Get values within lookback window around this geolocation's timestamp
    final valuesInWindow = _getValuesInLookbackWindow(geo.timestamp);

    if (valuesInWindow.isNotEmpty) {
      final aggregated = aggregateData(valuesInWindow);

      // Check if batch already exists and has data for this sensor - don't overwrite it
      final existingBatch = _sensorBatches[geoId];
      if (existingBatch != null &&
          existingBatch.aggregatedData.containsKey(title)) {
        // Skip - batch already has data for this sensor
      } else {
        final batch = _sensorBatches.putIfAbsent(
          geoId,
          () => SensorBatch(
            geoLocation: geo,
            aggregatedData: {},
            timestamp: DateTime.now(),
          ),
        );
        batch.aggregatedData[title] = aggregated;

        // Trigger flush to save the aggregated data immediately
        // Use Future.microtask to avoid blocking and allow other operations to complete
        Future.microtask(() async {
          await _flushBuffers();
        });
      }
      
      // Remove values that have been aggregated (timestamp <= geolocation timestamp)
      // They won't be used by future geolocations
      final cutoffTime = geo.timestamp.add(const Duration(microseconds: 1));
      _preGpsValues
          .removeWhere((entry) => !entry.timestamp.isAfter(cutoffTime));
    }
  }

  /// Performs deferred aggregation after lookback window closes
  void _performDeferredAggregation(int geoId, GeolocationData geo) {
    // Check if geolocation still exists in batches (might have been flushed)
    final batch = _sensorBatches[geoId];
    if (batch == null) {
      // Batch was already flushed or removed, skip aggregation
      return;
    }

    // Use batch's geolocation to ensure we have the latest data
    final batchGeo = batch.geoLocation;

    // Get values within lookback window around this geolocation's timestamp
    final valuesInWindow = _getValuesInLookbackWindow(batchGeo.timestamp);

    if (valuesInWindow.isNotEmpty) {
      final aggregated = aggregateData(valuesInWindow);

      // Check if batch already has data for this sensor - don't overwrite it
      if (batch.aggregatedData.containsKey(title)) {
        // Skip - batch already has data for this sensor
      } else {
        batch.aggregatedData[title] = aggregated;
        
        // Trigger flush to save the aggregated data immediately
        // Use Future.microtask to avoid blocking and allow other operations to complete
        Future.microtask(() async {
          await _flushBuffers();
        });
      }
      
      // Remove values that have been aggregated (timestamp <= geolocation timestamp)
      // They won't be used by future geolocations
      final cutoffTime =
          batchGeo.timestamp.add(const Duration(microseconds: 1));
      _preGpsValues
          .removeWhere((entry) => !entry.timestamp.isAfter(cutoffTime));
    }
  }


  void startListening() async {
    try {
      // Cancel existing subscriptions to prevent duplicates
      await _subscription?.cancel();
      await _geoSubscription?.cancel();
      
      _subscription = bleBloc
          .getCharacteristicStream(characteristicUuid)
          .listen((data) {
        onDataReceived(data);
      });

      _geoSubscription = geolocationBloc.geolocationStream.listen((geo) async {
        final geoId = geo.id;

        await _flushBuffers();

        // Create batch entry for this geolocation (if it doesn't exist)
        // This ensures the batch exists even if aggregation is deferred
        _sensorBatches.putIfAbsent(
          geoId,
          () => SensorBatch(
            geoLocation: geo,
            aggregatedData: {},
            timestamp: DateTime.now(),
          ),
        );

        // If sensor has a lookback window, defer aggregation until window closes
        // This ensures we capture all values that arrive within the window
        if (lookbackWindow != Duration.zero) {
          // Cancel any existing pending aggregation for this geolocation
          _cancelPendingAggregation(geoId);
          
          // Store geolocation for event-driven re-aggregation
          _pendingGeolocations[geoId] = geo;
          
          // Schedule aggregation after the lookback window closes using Future.delayed
          _scheduleDeferredAggregation(geoId, geo);
        } else {
          // No lookback window: aggregate immediately (backward compatible)
          _performImmediateAggregation(geo);
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
      // Handle error silently
    }
  }

  Future<void> stopListening() async {
    // Cancel all pending aggregations
    for (final geoId in _pendingAggregations.keys.toList()) {
      _cancelPendingAggregation(geoId);
    }
    _pendingAggregations.clear();
    _pendingGeolocations.clear();
    
    await _subscription?.cancel();
    _subscription = null;
    await _geoSubscription?.cancel();
    _geoSubscription = null;
    await _uploadSuccessSubscription?.cancel();
    _uploadSuccessSubscription = null;
    
    if (_recordingListener != null) {
      recordingBloc.isRecordingNotifier.removeListener(_recordingListener!);
      _recordingListener = null;
    }

    await _flushBuffers();
  }

  Future<void> flushBuffers() async {
    await _flushBuffers();
  }

  void clearBuffersForNewRecording() {
    // Cancel all pending aggregations
    for (final geoId in _pendingAggregations.keys.toList()) {
      _cancelPendingAggregation(geoId);
    }
    _pendingAggregations.clear();
    _pendingGeolocations.clear();
    _sensorBatches.clear();
    _preGpsValues.clear();
  }

  Future<void> _flushBuffers() async {
    final isRecording = recordingBloc.isRecording;

    // If recording stopped, trigger immediate aggregation for all pending aggregations
    if (!isRecording && _pendingAggregations.isNotEmpty) {
      final pendingGeoIds = _pendingAggregations.keys.toList();
      for (final geoId in pendingGeoIds) {
        _cancelPendingAggregation(geoId);
        
        // Perform immediate aggregation for this geolocation
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
      if (_preGpsValues.isNotEmpty && !isRecording) {
        // Process remaining sensor data when recording stops
        // Create a new geolocation for all buffered sensor data

        if (_sensorBatches.isNotEmpty) {
          // There are existing geolocations - process remaining values
          final lastBatch = _sensorBatches.values.last;
          if (lastBatch.geoLocation.id != Isar.autoIncrement &&
              lastBatch.geoLocation.id != 0) {
            // Use lookback window for the last batch as well
            final valuesInWindow =
                _getValuesInLookbackWindow(lastBatch.geoLocation.timestamp);
            if (valuesInWindow.isNotEmpty) {
              final aggregated = aggregateData(valuesInWindow);
              lastBatch.aggregatedData[title] = aggregated;
            }

            // Handle remaining values that don't belong to the last geolocation
            // With new logic: values belong to geo if timestamp <= geo timestamp
            // So remaining values are those with timestamp > lastGeoTimeUtc
            final lastGeoTimeUtc = lastBatch.geoLocation.timestamp.isUtc
                ? lastBatch.geoLocation.timestamp
                : lastBatch.geoLocation.timestamp.toUtc();

            final remainingValues = _preGpsValues
                .where((entry) => entry.timestamp.isAfter(lastGeoTimeUtc))
                .toList();

            // Get track from last batch's geolocation (since currentTrack may be null when recording stops)
            await lastBatch.geoLocation.track.load();
            final track = lastBatch.geoLocation.track.value;

            if (remainingValues.isNotEmpty && track != null) {
              final stopTimestamp = recordingBloc.lastRecordingStopTimestamp ??
                  DateTime.now().toUtc();

              // Check if a geolocation with this timestamp/location already exists
              GeolocationData? geolocationToUse;
              GeolocationData? existingGeolocation;
              try {
                final trackId = track.id;
                if (trackId != Isar.autoIncrement && trackId != 0) {
                  final geolocations = await isarService.geolocationService
                      .getGeolocationDataByTrackId(trackId);
                  try {
                    existingGeolocation = geolocations.firstWhere((geo) {
                      final timeDiff =
                          (geo.timestamp.difference(stopTimestamp)).abs();
                      final sameLocation =
                          (geo.latitude - lastBatch.geoLocation.latitude)
                                      .abs() <
                                  0.000001 &&
                              (geo.longitude - lastBatch.geoLocation.longitude)
                                      .abs() <
                                  0.000001;
                      return sameLocation && timeDiff.inMilliseconds < 100;
                    });
                  } catch (e) {
                    existingGeolocation = null;
                  }
                }
              } catch (e) {
                existingGeolocation = null;
              }

              if (existingGeolocation != null) {
                geolocationToUse = existingGeolocation;
              } else {
                geolocationToUse = GeolocationData()
                  ..latitude = lastBatch.geoLocation.latitude
                  ..longitude = lastBatch.geoLocation.longitude
                  ..speed = lastBatch.geoLocation.speed
                  ..timestamp = stopTimestamp
                  ..track.value = track;

                try {
                  final savedId = await isarService.geolocationService
                      .saveGeolocationData(geolocationToUse);
                  geolocationToUse.id = savedId;
                } catch (e) {
                  _preGpsValues.clear();
                  return;
                }
              }

              try {
                final valuesForNewGeo =
                    remainingValues.map((entry) => entry.values).toList();

                if (valuesForNewGeo.isNotEmpty) {
                  final aggregated = aggregateData(valuesForNewGeo);

                  final existingBatch = _sensorBatches[geolocationToUse.id];
                  if (existingBatch != null) {
                    existingBatch.aggregatedData[title] = aggregated;
                  } else {
                    final newBatch = SensorBatch(
                      geoLocation: geolocationToUse,
                      aggregatedData: {title: aggregated},
                      timestamp: DateTime.now(),
                    );
                    _sensorBatches[geolocationToUse.id] = newBatch;
                  }
                }
              } catch (e) {
                // Ignore aggregation errors during stop
              }

              final cutoffTime =
                  stopTimestamp.add(const Duration(microseconds: 1));
              _preGpsValues
                  .removeWhere((entry) => !entry.timestamp.isAfter(cutoffTime));
            } else {
              _preGpsValues.clear();
            }
          }
        } else {
          // No existing geolocations - create one for all buffered sensor data
          // Try to get track from recordingBloc, but if null, we can't create a geolocation
          final track = recordingBloc.currentTrack;
          if (track != null) {
            // Get timestamp from the latest sensor value
            final latestTimestamp = _preGpsValues
                .map((e) => e.timestamp)
                .reduce((a, b) => a.isAfter(b) ? a : b);

            // Check if a geolocation with this timestamp already exists
            GeolocationData? existingGeolocation;
            try {
              final trackId = track.id;
              if (trackId != Isar.autoIncrement && trackId != 0) {
                final geolocations = await isarService.geolocationService
                    .getGeolocationDataByTrackId(trackId);
                try {
                  existingGeolocation = geolocations.firstWhere(
                    (geo) {
                      final timeDiff =
                          (geo.timestamp.difference(latestTimestamp)).abs();
                      return timeDiff.inMilliseconds < 100;
                    },
                  );
                } catch (e) {
                  existingGeolocation = null;
                }
              }
            } catch (e) {
              existingGeolocation = null;
            }

            GeolocationData geolocationToUse;
            if (existingGeolocation != null) {
              geolocationToUse = existingGeolocation;
            } else {
              // Create new geolocation - use coordinates from last known position or default
              // Get last geolocation from track if available
              GeolocationData? lastGeo;
              try {
                final trackId = track.id;
                if (trackId != Isar.autoIncrement && trackId != 0) {
                  final geolocations = await isarService.geolocationService
                      .getGeolocationDataByTrackId(trackId);
                  if (geolocations.isNotEmpty) {
                    geolocations
                        .sort((a, b) => b.timestamp.compareTo(a.timestamp));
                    lastGeo = geolocations.first;
                  }
                }
              } catch (e) {
                // Ignore errors
              }

              geolocationToUse = GeolocationData()
                ..latitude = lastGeo?.latitude ?? 0.0
                ..longitude = lastGeo?.longitude ?? 0.0
                ..speed = lastGeo?.speed ?? 0.0
                ..timestamp = latestTimestamp
                ..track.value = track;

              try {
                final savedId = await isarService.geolocationService
                    .saveGeolocationData(geolocationToUse);
                geolocationToUse.id = savedId;
              } catch (e) {
                _preGpsValues.clear();
                return;
              }
            }

            try {
              // Aggregate all buffered values (they belong to this geolocation)
              final valuesForGeo = _preGpsValues
                  .where((entry) => !entry.timestamp.isAfter(latestTimestamp))
                  .map((entry) => entry.values)
                  .toList();

              if (valuesForGeo.isNotEmpty) {
                final aggregated = aggregateData(valuesForGeo);

                final existingBatch = _sensorBatches[geolocationToUse.id];
                if (existingBatch != null) {
                  existingBatch.aggregatedData[title] = aggregated;
                } else {
                  final newBatch = SensorBatch(
                    geoLocation: geolocationToUse,
                    aggregatedData: {title: aggregated},
                    timestamp: DateTime.now(),
                  );
                  _sensorBatches[geolocationToUse.id] = newBatch;
                }
                // Batch will be processed in the same _flushBuffers() call (line 741)
              }
            } catch (e) {
              // If processing fails, continue
            }

            // Clear all processed values
            _preGpsValues.clear();
          }
        }
      }

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
    } catch (e) {
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
