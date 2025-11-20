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
  StreamSubscription<List<double>>? _subscription;
  StreamSubscription<GeolocationData>? _geoSubscription;
  StreamSubscription<List<int>>? _uploadSuccessSubscription;
  
  final Map<int, SensorBatch> _sensorBatches = {};
  final List<TimestampedSensorValue> _preGpsValues = [];
  
  DirectUploadService? _directUploadService;
  VoidCallback? _recordingListener;
  bool _isFlushing = false;

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
      _preGpsValues.add(TimestampedSensorValue(
        values: data,
        // Use UTC to match geolocation timestamps which come from GPS device
        timestamp: DateTime.now().toUtc(),
      ));

      // Clean up old values periodically
      _cleanupOldValues();
    }
    
    _valueController.add(data);
  }

  /// Removes values older than maxBufferAge from the buffer
  void _cleanupOldValues() {
    final now = DateTime.now();
    final cutoffTime = now.subtract(maxBufferAge);
    _preGpsValues.removeWhere((entry) => entry.timestamp.isBefore(cutoffTime));
  }

  /// Gets all sensor values within the lookback window around a geolocation timestamp
  /// Returns values that fall within [geoTime - lookbackWindow, geoTime + lookbackWindow]
  /// (inclusive of boundaries)
  /// Both geoTime and sensor timestamps should be in UTC for correct comparison
  List<List<double>> _getValuesInLookbackWindow(DateTime geoTime) {
    if (lookbackWindow == Duration.zero) {
      // No lookback: return all current values (backward compatible)
      return _preGpsValues.map((entry) => entry.values).toList();
    }

    // Ensure geoTime is in UTC for comparison with sensor timestamps
    final geoTimeUtc = geoTime.isUtc ? geoTime : geoTime.toUtc();
    final windowStart = geoTimeUtc.subtract(lookbackWindow);
    final windowEnd = geoTimeUtc.add(lookbackWindow);

    final valuesInWindow = _preGpsValues
        .where((entry) =>
            !entry.timestamp.isBefore(windowStart) &&
            !entry.timestamp.isAfter(windowEnd))
        .map((entry) => entry.values)
        .toList();

    return valuesInWindow;
  }

  /// Removes values that are older than the geolocation timestamp minus lookback window
  /// This keeps values that might be needed for future geolocations
  void _removeValuesOlderThan(DateTime geoTime) {
    if (lookbackWindow == Duration.zero) {
      // No lookback: clear all values (backward compatible)
      _preGpsValues.clear();
      return;
    }

    // Ensure geoTime is in UTC for comparison with sensor timestamps
    final geoTimeUtc = geoTime.isUtc ? geoTime : geoTime.toUtc();
    // Only remove values that are definitely too old to be used by future geolocations
    // Keep values within the lookback window for potential future use
    final cutoffTime = geoTimeUtc
        .subtract(lookbackWindow)
        .subtract(const Duration(milliseconds: 100));
    _preGpsValues.removeWhere((entry) => entry.timestamp.isBefore(cutoffTime));
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
            _sensorBatches
                .putIfAbsent(
                  geoId,
                  () => SensorBatch(
                    geoLocation: geo,
                    aggregatedData: {},
                    timestamp: DateTime.now(),
                  ),
                )
                .aggregatedData[title] = aggregated;
          }
          
          // Remove values that are too old to be used by future geolocations
          _removeValuesOlderThan(geo.timestamp);
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
    _sensorBatches.clear();
    _preGpsValues.clear();
  }

  Future<void> _flushBuffers() async {
    final isRecording = recordingBloc.isRecording;

    if (_sensorBatches.isEmpty && _preGpsValues.isEmpty) {
      return;
    }

    if (_isFlushing) {
      return;
    }
    _isFlushing = true;

    try {
      if (_preGpsValues.isNotEmpty &&
          !isRecording &&
          _sensorBatches.isNotEmpty) {
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

          // Handle remaining values that are outside the lookback window
          // Create a new geolocation with same coordinates but timestamp from sensor data
          final lastGeoTimeUtc = lastBatch.geoLocation.timestamp.isUtc
              ? lastBatch.geoLocation.timestamp
              : lastBatch.geoLocation.timestamp.toUtc();
          final windowEnd = lastGeoTimeUtc.add(lookbackWindow);

          final remainingValues = _preGpsValues
              .where((entry) => entry.timestamp.isAfter(windowEnd))
              .toList();

          if (remainingValues.isNotEmpty &&
              recordingBloc.currentTrack != null) {
            // Get timestamp from the latest sensor value
            final latestTimestamp = remainingValues
                .map((e) => e.timestamp)
                .reduce((a, b) => a.isAfter(b) ? a : b);

            // Check if a geolocation with this timestamp already exists
            // (created by another sensor that flushed buffers first)
            GeolocationData? existingGeolocation;
            try {
              final trackId = recordingBloc.currentTrack!.id;
              if (trackId != Isar.autoIncrement && trackId != 0) {
                final geolocations = await isarService.geolocationService
                    .getGeolocationDataByTrackId(trackId);
                // Find geolocation with same timestamp (within 100ms tolerance)
                try {
                  existingGeolocation = geolocations.firstWhere(
                    (geo) {
                      final timeDiff =
                          (geo.timestamp.difference(latestTimestamp)).abs();
                      return timeDiff.inMilliseconds < 100;
                    },
                  );
                } catch (e) {
                  // No matching geolocation found
                  existingGeolocation = null;
                }
              }
            } catch (e) {
              // If query fails, proceed to create new geolocation
              existingGeolocation = null;
            }

            GeolocationData geolocationToUse;
            if (existingGeolocation != null) {
              // Reuse existing geolocation created by another sensor
              geolocationToUse = existingGeolocation;
            } else {
              // Create new geolocation with same coordinates but new timestamp
              geolocationToUse = GeolocationData()
                ..latitude = lastBatch.geoLocation.latitude
                ..longitude = lastBatch.geoLocation.longitude
                ..speed = lastBatch.geoLocation.speed
                ..timestamp = latestTimestamp
                ..track.value = recordingBloc.currentTrack;

              try {
                // Save the new geolocation
                final savedId = await isarService.geolocationService
                    .saveGeolocationData(geolocationToUse);
                geolocationToUse.id = savedId;
              } catch (e) {
                // If saving fails, continue without creating new geolocation
                _preGpsValues.clear();
                return;
              }
            }

            try {
              // Aggregate only the remaining values (those outside the last geolocation's window)
              // Use lookback window around the new timestamp, but only consider remaining values
              final newWindowStart = latestTimestamp.subtract(lookbackWindow);
              final newWindowEnd = latestTimestamp.add(lookbackWindow);

              final valuesForNewGeo = remainingValues
                  .where((entry) =>
                      !entry.timestamp.isBefore(newWindowStart) &&
                      !entry.timestamp.isAfter(newWindowEnd))
                  .map((entry) => entry.values)
                  .toList();

              if (valuesForNewGeo.isNotEmpty) {
                final aggregated = aggregateData(valuesForNewGeo);

                // Check if batch already exists (if reusing existing geolocation)
                final existingBatch = _sensorBatches[geolocationToUse.id];
                if (existingBatch != null) {
                  // Add to existing batch (another sensor already created it)
                  existingBatch.aggregatedData[title] = aggregated;
                } else {
                  // Create a new batch for this geolocation
                  final newBatch = SensorBatch(
                    geoLocation: geolocationToUse,
                    aggregatedData: {title: aggregated},
                    timestamp: DateTime.now(),
                  );
                  _sensorBatches[geolocationToUse.id] = newBatch;
                }
              }
            } catch (e) {
              // If processing fails, continue without creating new geolocation
            }
          }

          // Clear all remaining values when recording stops
          _preGpsValues.clear();
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
