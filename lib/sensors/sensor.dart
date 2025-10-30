import 'dart:async';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
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
  final SettingsBloc settingsBloc;
  final IsarService isarService;

  final StreamController<List<double>> _valueController =
      StreamController<List<double>>.broadcast();
  StreamSubscription<List<double>>? _subscription;
  StreamSubscription<GeolocationData>? _geoSubscription;
  Timer? _batchTimer;
  final Duration _batchTimeout = Duration(seconds: 5);
  
  final Map<int, SensorBatch> _sensorBatches = {};
  final List<List<double>> _preGpsValues = [];
  
  GeolocationData? _lastGeolocation;
  DirectUploadService? _directUploadService;
  VoidCallback? _recordingListener;
  bool _isFlushing = false;

  Sensor(
    this.characteristicUuid,
    this.title,
    this.attributes,
    this.bleBloc,
    this.geolocationBloc,
    this.recordingBloc,
    this.settingsBloc,
    this.isarService,
  );

  Stream<List<double>> get valueStream => _valueController.stream;

  List<double> aggregateData(List<List<double>> rawData);

  int get uiPriority;

  void setDirectUploadService(DirectUploadService uploadService) {
    _directUploadService = uploadService;
    
    uploadService.setUploadSuccessCallback((uploadedGeoIds) {
      for (final geoId in uploadedGeoIds) {
        final batch = _sensorBatches[geoId];
        if (batch != null) {
          batch.isUploaded = true;
          _sensorBatches.remove(geoId);
        }
      }
    });

    uploadService.setPermanentDisableCallback(() {
      for (final batch in _sensorBatches.values) {
        batch.isUploadPending = false;
      }
    });
  }

  void onDataReceived(List<double> data) {
    if (data.isNotEmpty && recordingBloc.isRecording) {
      if (_lastGeolocation != null) {
        final geoId = _lastGeolocation!.id;
        
        _sensorBatches.putIfAbsent(
          geoId,
          () => SensorBatch(
            geoLocation: _lastGeolocation!,
            aggregatedData: {},
            timestamp: DateTime.now(),
          ),
        );
        
        _sensorBatches[geoId]!.aggregatedData
            .putIfAbsent(title, () => [])
            .addAll(data);
      } else {
        _preGpsValues.add(data);
      }
    }
    
    _valueController.add(data);
  }

  void startListening() async {
    try {
      _subscription = bleBloc
          .getCharacteristicStream(characteristicUuid)
          .listen((data) {
        onDataReceived(data);
      });

      _geoSubscription = geolocationBloc.geolocationStream.listen((geo) {
        _lastGeolocation = geo;

        if (_preGpsValues.isNotEmpty) {
          final geoId = geo.id;
          
          _sensorBatches.putIfAbsent(
            geoId,
            () => SensorBatch(
              geoLocation: geo,
              aggregatedData: {},
              timestamp: DateTime.now(),
            ),
          );
          
          final aggregated = aggregateData(_preGpsValues);
          _sensorBatches[geoId]!.aggregatedData
              .putIfAbsent(title, () => [])
              .addAll(aggregated);
          
          _preGpsValues.clear();
        }
      });

      _batchTimer = Timer.periodic(_batchTimeout, (_) async {
        await _flushBuffers();
      });

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
    _batchTimer?.cancel();
    _batchTimer = null;
    
    if (_recordingListener != null) {
      recordingBloc.isRecordingNotifier.removeListener(_recordingListener!);
      _recordingListener = null;
    }

    await _flushBuffers();
  }

  Future<void> flushBuffers() async {
    await _flushBuffers();
  }

  void clearBuffersOnRecordingStop() {
    if (!recordingBloc.isRecording) {
      _sensorBatches.clear();
    }
  }

  void clearBuffersForNewRecording() {
    _sensorBatches.clear();
  }

  Future<void> _flushBuffers() async {
    if (_sensorBatches.isEmpty) {
      return;
    }

    if (_isFlushing) {
      return;
    }
    _isFlushing = true;

    try {
      final batchesToProcess = _sensorBatches.values
          .where((b) => !b.isSavedToDb && !b.isUploaded)
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

        if (recordingBloc.isRecording) {
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

      if (_directUploadService != null &&
          recordingBloc.isRecording &&
          uploadData.isNotEmpty &&
          _directUploadService!.isEnabled) {
        
        final batchRefs = geoIdsToSave
            .map((id) => _sensorBatches[id])
            .where((b) => b != null && !b.isUploadPending && !b.isUploaded)
            .cast<SensorBatch>()
            .toList();

        if (batchRefs.isNotEmpty) {
          _directUploadService!.queueBatchesForUpload(batchRefs);
        }
      }
    } catch (e) {
      debugPrint('[Sensor:$title] Error in _flushBuffers: $e');
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
