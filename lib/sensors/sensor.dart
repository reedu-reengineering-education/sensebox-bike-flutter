import 'dart:async';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

abstract class Sensor {
  final String characteristicUuid;
  final String title;
  final List<String> attributes;

  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final IsarService isarService;
  DirectUploadService? _directUploadService;
  StreamSubscription<List<double>>? _subscription;
  VoidCallback? _recordingListener;

  final StreamController<List<double>> _valueController =
      StreamController<List<double>>.broadcast();
  Stream<List<double>> get valueStream => _valueController.stream;
  static const Duration _batchTimeout = Duration(seconds: 5);
  Timer? _batchTimer;

  // Buffers for batching
  final List<Map<String, dynamic>> _sensorBuffer = [];
  final List<GeolocationData> _gpsBuffer = [];

  Sensor(
    this.characteristicUuid,
    this.title,
    this.attributes,
    this.bleBloc,
    this.geolocationBloc,
    this.recordingBloc,
    this.isarService,
  );

  int get uiPriority;

  void setDirectUploadService(DirectUploadService uploadService) {
    _directUploadService = uploadService;
  }

  void onDataReceived(List<double> data) {
    if (data.isNotEmpty && recordingBloc.isRecording) {
      final now = DateTime.now();
      for (int i = 0; i < data.length; i++) {
        _sensorBuffer.add({
          'timestamp': now,
          'value': data[i],
          'index': i,
          'sensor': title,
          'attribute': attributes.isNotEmpty ? attributes[i] : null,
        });
        
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

      geolocationBloc.geolocationStream.listen((geo) {
        if (geo != null) {
          _gpsBuffer.add(geo);
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
      debugPrint('Error starting sensor: $e');
    }
  }

  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    _batchTimer?.cancel();
    _batchTimer = null;
    
    // Remove recording listener
    if (_recordingListener != null) {
      recordingBloc.isRecordingNotifier.removeListener(_recordingListener!);
      _recordingListener = null;
    }

    await _flushBuffers();
  }

  Future<void> flushBuffers() async {
    await _flushBuffers();
  }

  Future<void> _flushBuffers() async {
    if (_sensorBuffer.isEmpty) return;
    
    if (_directUploadService != null && recordingBloc.isRecording) {
      _directUploadService!.addBufferedDataForUpload(
          List.from(_sensorBuffer), List.from(_gpsBuffer));
    }
    
    final List<SensorData> batch = [];
    for (final entry in List.from(_sensorBuffer)) {
      final DateTime sensorTs = entry['timestamp'] as DateTime;
      final double value = entry['value'] as double;
      //final int index = entry['index'] as int;
      final String sensorTitle = entry['sensor'] as String;
      final String? attr = entry['attribute'] as String?;

      GeolocationData? gps = List.from(_gpsBuffer)
          .where((g) =>
              g.timestamp.isBefore(sensorTs) ||
              g.timestamp.isAtSameMomentAs(sensorTs))
          .fold<GeolocationData?>(
              null,
              (prev, g) => prev == null || g.timestamp.isAfter(prev.timestamp)
                  ? g
                  : prev);
      if (gps == null) continue;

      if (gps.id == Isar.autoIncrement || gps.id == 0) {
        gps.id = await isarService.geolocationService.saveGeolocationData(gps);
      }
      final sensorData = SensorData()
        ..characteristicUuid = characteristicUuid
        ..title = sensorTitle
        ..value = value
        ..attribute = attr
        ..geolocationData.value = gps;
      batch.add(sensorData);
    }
    if (batch.isNotEmpty) {
      await isarService.sensorService.saveSensorDataBatch(batch);
    }
    _sensorBuffer.clear();
    if (_gpsBuffer.length > 100) {
      _gpsBuffer.removeRange(0, _gpsBuffer.length - 100);
    }
  }

  Widget buildWidget();
  List<double> aggregateData(List<List<double>> valueBuffer);

  void dispose() {
    stopListening();
    _valueController.close();
  }
}
