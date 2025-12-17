import 'dart:async' show StreamSubscription, StreamController;
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
import 'package:sensebox_bike/models/timestamped_sensor_value.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/utils/date_utils.dart';
import 'package:sensebox_bike/utils/geolocation_utils.dart';
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

  final Map<int, GeolocationData> _pendingGeolocations = {};

  Duration get lookbackWindow => Duration.zero;

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

      if (lookbackWindow != Duration.zero) {
        _checkAndTriggerPendingAggregations(sensorTimestamp);
      }

      _cleanupOldValuesIfBufferExceedsThreshold();
      _timestampedValueController.add(timestampedValue);
    }
    
    _valueController.add(data);
  }

  void _cleanupOldValuesIfBufferExceedsThreshold() {
    if (_preGpsValues.length < 1000) {
      return;
    }

    final cutoffTime = DateTime.now().toUtc().subtract(maxBufferAge);
    _preGpsValues.removeWhere((entry) => entry.timestamp.isBefore(cutoffTime));
  }

  void _checkAndTriggerPendingAggregations(DateTime sensorTimestamp) {
    if (_pendingGeolocations.isEmpty) return;

    final now = DateTime.now().toUtc();
    final geoIdsToProcess = <int>[];

    // Check each pending geolocation
    for (final entry in _pendingGeolocations.entries) {
      final geoId = entry.key;
      final geo = entry.value;
      final geoTimeUtc = toUtc(geo.timestamp);

      final batch = _sensorBatches[geoId];
      final geoArrivalTime = batch?.timestamp ?? geo.timestamp;
      final waitUntilTime = geoArrivalTime.add(lookbackWindow);

      final sensorTimestampUtc = toUtc(sensorTimestamp);
      if (sensorTimestampUtc.isAfter(geoTimeUtc) ||
          !now.isBefore(waitUntilTime)) {
        geoIdsToProcess.add(geoId);
      }
    }

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
    return getValuesInLookbackWindow(
      geoTime,
      _preGpsValues,
      _sensorBatches.values.toList(),
      lookbackWindow,
    );
  }

  SensorBatch _createSensorBatch(GeolocationData geo) {
    return SensorBatch(
      geoLocation: geo,
      aggregatedData: {},
      timestamp: DateTime.now(),
    );
  }

  void _setAggregatedDataOnBatch(
      int geoId, GeolocationData geo, List<double> aggregated) {
    final existingBatch = _sensorBatches[geoId];
    if (existingBatch != null &&
        existingBatch.aggregatedData.containsKey(title)) {
      return;
    }

    final batch =
        _sensorBatches.putIfAbsent(geoId, () => _createSensorBatch(geo));
    batch.aggregatedData[title] = aggregated;
    flushBuffers();
  }

  void _performImmediateAggregation(GeolocationData geo) {
    final geoId = geo.id;
    final valuesInWindow = _getValuesInLookbackWindow(geo.timestamp);

    if (valuesInWindow.isNotEmpty) {
      final aggregated = aggregateData(valuesInWindow);
      _setAggregatedDataOnBatch(geoId, geo, aggregated);
      _cleanupOldValuesIfBufferExceedsThreshold();
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
      _setAggregatedDataOnBatch(geoId, geo, aggregated);
      _cleanupOldValuesIfBufferExceedsThreshold();
    }
  }

  Future<GeolocationData?> _findExistingGeolocation(
    int trackId,
    DateTime timestamp, {
    double? latitude,
    double? longitude,
  }) async {
    if (trackId == Isar.autoIncrement || trackId == 0) {
      return null;
    }

    try {
      final geolocations = await isarService.geolocationService
          .getGeolocationDataByTrackId(trackId);
      return findMatchingGeolocation(
        geolocations,
        timestamp,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
      return null;
    }
  }

  SensorData _createSensorData(
    GeolocationData geolocation,
    double value,
    String? attribute,
  ) {
    return SensorData()
      ..characteristicUuid = characteristicUuid
      ..title = title
      ..value = value
      ..attribute = attribute
      ..geolocationData.value = geolocation;
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
            if (_isListening) {
              return;
            }
            startListening();
          });
        },
        cancelOnError: false,
      );

      _geoSubscription = geolocationBloc.geolocationStream.listen(
        (geo) async {
          final geoId = geo.id;

          await flushBuffers();

          _sensorBatches.putIfAbsent(geoId, () => _createSensorBatch(geo));

          if (lookbackWindow != Duration.zero) {
            _scheduleDeferredAggregation(geoId, geo);
          } else {
            _performImmediateAggregation(geo);
          }
        },
        onError: (error, stack) {
          ErrorService.handleError(error, stack);
        },
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
    _pendingGeolocations.clear();
    _sensorBatches.clear();
    _preGpsValues.clear();
  }

  Future<void> flushBuffers() async {
    final isRecording = recordingBloc.isRecording;

    if (!isRecording && _pendingGeolocations.isNotEmpty) {
      final pendingGeoIds = _pendingGeolocations.keys.toList();
      for (final geoId in pendingGeoIds) {
        _pendingGeolocations.remove(geoId);

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
        if (_sensorBatches.isNotEmpty) {
          final lastBatch = _sensorBatches.values.last;
          if (lastBatch.geoLocation.id != Isar.autoIncrement &&
              lastBatch.geoLocation.id != 0) {
            final valuesInWindow =
                _getValuesInLookbackWindow(lastBatch.geoLocation.timestamp);
            if (valuesInWindow.isNotEmpty) {
              final aggregated = aggregateData(valuesInWindow);
              lastBatch.aggregatedData[title] = aggregated;
            }

            final lastGeoTimeUtc = toUtc(lastBatch.geoLocation.timestamp);

            final remainingValues = _preGpsValues
                .where((entry) => entry.timestamp.isAfter(lastGeoTimeUtc))
                .toList();

            await lastBatch.geoLocation.track.load();
            final track = lastBatch.geoLocation.track.value;

            if (remainingValues.isNotEmpty && track != null) {
              final stopTimestamp = recordingBloc.lastRecordingStopTimestamp ??
                  DateTime.now().toUtc();

              GeolocationData? geolocationToUse;
              final existingGeolocation = await _findExistingGeolocation(
                track.id,
                stopTimestamp,
                latitude: lastBatch.geoLocation.latitude,
                longitude: lastBatch.geoLocation.longitude,
              );

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
                  _setAggregatedDataOnBatch(
                      geolocationToUse.id, geolocationToUse, aggregated);
                }
              } catch (e, stack) {
                ErrorService.handleError(e, stack);
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
          final track = recordingBloc.currentTrack;
          if (track != null) {
            final latestTimestamp = _preGpsValues
                .map((e) => e.timestamp)
                .reduce((a, b) => a.isAfter(b) ? a : b);

            final existingGeolocation = await _findExistingGeolocation(
              track.id,
              latestTimestamp,
            );

            GeolocationData geolocationToUse;
            if (existingGeolocation != null) {
              geolocationToUse = existingGeolocation;
            } else {
              GeolocationData? lastGeo;
              try {
                final trackId = track.id;
                if (trackId != Isar.autoIncrement && trackId != 0) {
                  final geolocations = await isarService.geolocationService
                      .getGeolocationDataByTrackId(trackId);
                  lastGeo = findLatestGeolocation(geolocations);
                }
              } catch (e, stack) {
                ErrorService.handleError(e, stack);
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
              final valuesForGeo = _preGpsValues
                  .where((entry) => !entry.timestamp.isAfter(latestTimestamp))
                  .map((entry) => entry.values)
                  .toList();

              if (valuesForGeo.isNotEmpty) {
                final aggregated = aggregateData(valuesForGeo);
                _setAggregatedDataOnBatch(
                    geolocationToUse.id, geolocationToUse, aggregated);
              }
            } catch (e, stack) {
              ErrorService.handleError(e, stack);
            }

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
            dbBatch.add(
                _createSensorData(geolocation, sensorData[j], attributes[j]));
          }
        } else {
          dbBatch.add(_createSensorData(
            geolocation,
            sensorData.isNotEmpty ? sensorData[0] : 0.0,
            null,
          ));
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
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
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
