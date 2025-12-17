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
  
  // Track pending geolocation data for event-driven re-aggregation
  // Key: geoId, Value: GeolocationData with timestamp for window checking
  // Also used to track pending deferred aggregations (removed when cancelled or executed)
  final Map<int, GeolocationData> _pendingGeolocations = {};

  /// Lookback window duration in milliseconds for retroactive aggregation
  /// Sensors can override this to customize the time window
  /// Default is 0ms (no lookback) for backward compatibility
  Duration get lookbackWindow => Duration.zero;

  /// Maximum age of values to keep in buffer (for cleanup)
  /// Values older than this will be removed as a safety net
  Duration get maxBufferAge => const Duration(minutes: 2);

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

      // Safety cleanup: only clean up very old data if buffer gets too large
      _cleanupOldValuesIfBufferTooLarge();
      
      // Emit timestamped value for CSV logger
      _timestampedValueController.add(timestampedValue);
    }
    
    _valueController.add(data);
  }

  void _cleanupOldValuesIfBufferTooLarge() {
    final cutoffTime = DateTime.now().toUtc().subtract(maxBufferAge);
    _preGpsValues.removeWhere((entry) => entry.timestamp.isBefore(cutoffTime));
    
    if (_preGpsValues.length >= 1000) {
      final aggressiveCutoff =
          DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      _preGpsValues
          .removeWhere((entry) => entry.timestamp.isBefore(aggressiveCutoff));
    }
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
      final geo = _pendingGeolocations.remove(geoId);
      if (geo != null) {
        _performDeferredAggregation(geoId, geo);
      }
    }
  }

  void _scheduleDeferredAggregation(int geoId, GeolocationData geo) {
    final batch = _sensorBatches[geoId];
    final geoArrivalTime = batch?.timestamp ?? DateTime.now().toUtc();
    final waitUntilTime = geoArrivalTime.add(lookbackWindow);
    final delay = waitUntilTime.difference(DateTime.now().toUtc());

    _pendingGeolocations[geoId] = geo;

    Future.delayed(delay.isNegative ? Duration.zero : delay, () {
      if (_pendingGeolocations.containsKey(geoId)) {
        _performDeferredAggregation(geoId, geo);
        _pendingGeolocations.remove(geoId);
      }
    });
  }


  List<List<double>> _getValuesInLookbackWindow(DateTime geoTime) {
    if (lookbackWindow == Duration.zero) {
      return _preGpsValues.map((entry) => entry.values).toList();
    }

    final geoTimeUtc = geoTime.isUtc ? geoTime : geoTime.toUtc();
    
    final otherBatches = _sensorBatches.values.where((b) {
      return (b.geoLocation.timestamp.difference(geoTimeUtc))
              .abs()
              .inMilliseconds >
          100;
    }).toList();

    final DateTime windowStart;
    if (otherBatches.isEmpty) {
      if (_preGpsValues.isEmpty) {
        windowStart = geoTimeUtc.subtract(const Duration(days: 1));
      } else {
        final earliestReading = _preGpsValues
            .map((e) => e.timestamp)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        windowStart = earliestReading.isAfter(geoTimeUtc)
            ? geoTimeUtc.subtract(const Duration(days: 1))
            : earliestReading;
      }
    } else {
      final previousGeoTime = otherBatches
          .map((b) => b.geoLocation.timestamp)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      windowStart =
          previousGeoTime.isUtc ? previousGeoTime : previousGeoTime.toUtc();
    }

    return _preGpsValues
        .where((entry) =>
            !entry.timestamp.isBefore(windowStart) &&
            !entry.timestamp.isAfter(geoTimeUtc))
        .map((entry) => entry.values)
        .toList();
  }

  void _performImmediateAggregation(GeolocationData geo) {
    final geoId = geo.id;
    final valuesInWindow = _getValuesInLookbackWindow(geo.timestamp);

    if (valuesInWindow.isNotEmpty) {
      final aggregated = aggregateData(valuesInWindow);

      final existingBatch = _sensorBatches[geoId];
      if (existingBatch != null &&
          existingBatch.aggregatedData.containsKey(title)) {
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

        flushBuffers();
      }
      
      _cleanupOldValuesIfBufferTooLarge();
    }
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
      } else {
        batch.aggregatedData[title] = aggregated;
        
        flushBuffers();
      }
      
      _cleanupOldValuesIfBufferTooLarge();
    }
  }


  void startListening() async {
    if (_isListening) {
      return;
    }
    
    try {
      _isListening = true;

      if (_geoSubscription != null) {
        await _geoSubscription?.cancel();
        _geoSubscription = null;
      }
      await _subscription?.cancel();
      
      _subscription = bleBloc
          .getCharacteristicStream(characteristicUuid)
          .listen(
        (data) => onDataReceived(data),
        onError: (error) {
          _isListening = false;
          Future.delayed(const Duration(seconds: 1), () {
            startListening();
          });
        },
        cancelOnError: false,
      );

      _geoSubscription = geolocationBloc.geolocationStream.listen(
        (geo) async {
          final geoId = geo.id;
          
          await flushBuffers();

          _sensorBatches.putIfAbsent(
            geoId,
            () => SensorBatch(
              geoLocation: geo,
              aggregatedData: {},
              timestamp: DateTime.now(),
            ),
          );

          if (lookbackWindow != Duration.zero) {
            _pendingGeolocations.remove(geoId);
            _pendingGeolocations[geoId] = geo;
            _scheduleDeferredAggregation(geoId, geo);
          } else {
            _performImmediateAggregation(geo);
          }
        },
        onError: (error) {},
        cancelOnError: false,
      );

      if (_recordingListener != null) {
        recordingBloc.isRecordingNotifier.removeListener(_recordingListener!);
      }
      
      _recordingListener = () {
        if (!recordingBloc.isRecording) {
          flushBuffers();
        }
      };
      recordingBloc.isRecordingNotifier.addListener(_recordingListener!);
    } catch (e) {
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    
    _pendingGeolocations.clear();
    
    await _subscription?.cancel();
    _subscription = null;
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

    await flushBuffers();
  }


  void clearBuffersForNewRecording() {
    // Cancel all pending aggregations
    _pendingGeolocations.clear();
    _sensorBatches.clear();
    _preGpsValues.clear();
  }

  Future<void> flushBuffers() async {
    final isRecording = recordingBloc.isRecording;

    // If recording stopped, trigger immediate aggregation for all pending aggregations
    if (!isRecording && _pendingGeolocations.isNotEmpty) {
      final pendingGeoIds = _pendingGeolocations.keys.toList();
      for (final geoId in pendingGeoIds) {
        _pendingGeolocations.remove(geoId);
        
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
                // Batch will be processed in the same flushBuffers() call (line 741)
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
