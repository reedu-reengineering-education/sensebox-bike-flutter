import 'dart:async';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
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
  final IsarService isarService;

  final StreamController<List<double>> _valueController =
      StreamController<List<double>>.broadcast();
  StreamSubscription<List<double>>? _subscription;
  StreamSubscription<GeolocationData>? _geoSubscription;
  StreamSubscription<List<int>>? _uploadSuccessSubscription;
  
  final Map<int, SensorBatch> _sensorBatches = {};
  final List<List<double>> _preGpsValues = [];
  
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
    this.isarService,
  );

  Stream<List<double>> get valueStream => _valueController.stream;

  List<double> aggregateData(List<List<double>> rawData);

  int get uiPriority;

  void setDirectUploadService(DirectUploadService uploadService) {
    debugPrint('[Sensor:$title] setDirectUploadService: Setting direct upload service (enabled: ${uploadService.isEnabled})');
    _directUploadService = uploadService;
    
    _uploadSuccessSubscription?.cancel();
    _uploadSuccessSubscription =
        uploadService.uploadSuccessStream.listen((uploadedGeoIds) {
      for (final geoId in uploadedGeoIds) {
        final batch = _sensorBatches[geoId];
        if (batch != null) {
          batch.isUploaded = true;
          _sensorBatches.remove(geoId);
        }
      }
    });
  }

  void onDataReceived(List<double> data) {
    if (data.isNotEmpty && recordingBloc.isRecording) {
      _preGpsValues.add(data);
      debugPrint('[Sensor:$title] onDataReceived: Received ${data.length} values (preGpsValues count: ${_preGpsValues.length})');
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

      _geoSubscription = geolocationBloc.geolocationStream.listen((geo) async {
        final geoId = geo.id;
        debugPrint('[Sensor:$title] Geolocation received: geoId=$geoId, preGpsValues=${_preGpsValues.length}, recording=${recordingBloc.isRecording}');

        await _flushBuffers();

        if (_preGpsValues.isNotEmpty) {
          final aggregated = aggregateData(_preGpsValues);
          debugPrint('[Sensor:$title] Aggregating ${_preGpsValues.length} preGpsValues into batch for geoId=$geoId');
          
          _sensorBatches.putIfAbsent(
            geoId,
            () => SensorBatch(
              geoLocation: geo,
              aggregatedData: {},
              timestamp: DateTime.now(),
            ),
              )
              .aggregatedData[title] = aggregated;
          
          _preGpsValues.clear();
        }
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

      // Diagnostic logging for direct upload
      if (_directUploadService == null) {
        debugPrint('[Sensor:$title] _flushBuffers: DirectUploadService is NULL');
      } else if (!recordingBloc.isRecording) {
        debugPrint('[Sensor:$title] _flushBuffers: Recording is NOT active');
      } else if (uploadData.isEmpty) {
        debugPrint('[Sensor:$title] _flushBuffers: uploadData is EMPTY (no sensor data to upload)');
      } else if (!_directUploadService!.isEnabled) {
        debugPrint('[Sensor:$title] _flushBuffers: DirectUploadService is DISABLED');
      } else {
        debugPrint('[Sensor:$title] _flushBuffers: Conditions met - checking batches. uploadData keys: ${uploadData.keys.length}, geoIdsToSave: $geoIdsToSave');
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
          debugPrint('[Sensor:$title] _flushBuffers: Calling queueBatchesForUpload with ${batchRefs.length} batches');
          _directUploadService!.queueBatchesForUpload(batchRefs);
        } else {
          debugPrint('[Sensor:$title] _flushBuffers: batchRefs is EMPTY (all batches already uploaded/pending)');
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
