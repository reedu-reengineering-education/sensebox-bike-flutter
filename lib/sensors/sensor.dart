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
  static const Duration _batchTimeout = Duration(seconds: 10);
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
    
    // Group sensor readings by geolocation
    final Map<GeolocationData, List<Map<String, dynamic>>>
        readingsByGeolocation = {};
    
    for (final entry in List.from(_sensorBuffer)) {
      final DateTime sensorTs = entry['timestamp'] as DateTime;

      // Find the closest GPS point (before or at the same time)
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

      // Group readings by geolocation
      readingsByGeolocation.putIfAbsent(gps, () => []).add(entry);
    }

    // Save aggregated data to database
    final List<SensorData> batch = [];
    for (final entry in readingsByGeolocation.entries) {
      final GeolocationData gps = entry.key;
      final List<Map<String, dynamic>> readings = entry.value;

      // Save geolocation if needed
      if (gps.id == Isar.autoIncrement || gps.id == 0) {
        gps.id = await isarService.geolocationService.saveGeolocationData(gps);
      }
      
      // Group readings by sensor type and timestamp to reconstruct full arrays
      final Map<DateTime, Map<int, double>> readingsByTimestamp = {};
      for (final reading in readings) {
        final DateTime timestamp = reading['timestamp'] as DateTime;
        final int index = reading['index'] as int;
        final double value = reading['value'] as double;

        readingsByTimestamp
            .putIfAbsent(timestamp, () => {})
            .putIfAbsent(index, () => value);
      }

      // Reconstruct full arrays for each timestamp and aggregate
      final List<List<double>> fullValueArrays = [];
      for (final timestampEntry in readingsByTimestamp.entries) {
        final Map<int, double> indexValues = timestampEntry.value;
        final List<double> fullArray =
            List.filled(attributes.isNotEmpty ? attributes.length : 1, 0.0);

        for (final indexEntry in indexValues.entries) {
          final int index = indexEntry.key;
          final double value = indexEntry.value;
          if (index < fullArray.length) {
            fullArray[index] = value;
          }
        }

        fullValueArrays.add(fullArray);
      }

      // Aggregate the values using the sensor's aggregation method
      if (fullValueArrays.isNotEmpty) {
        final aggregatedValues = aggregateData(fullValueArrays);

        // Create sensor data for each attribute
        if (attributes.isNotEmpty) {
          // Multi-value sensor (like finedust, surface_classification)
          for (int i = 0;
              i < attributes.length && i < aggregatedValues.length;
              i++) {
            final sensorData = SensorData()
              ..characteristicUuid = characteristicUuid
              ..title = title
              ..value = aggregatedValues[i]
              ..attribute = attributes[i]
              ..geolocationData.value = gps;
            batch.add(sensorData);
          }
        } else {
          // Single-value sensor (like temperature, humidity)
          final sensorData = SensorData()
            ..characteristicUuid = characteristicUuid
            ..title = title
            ..value = aggregatedValues.isNotEmpty ? aggregatedValues[0] : 0.0
            ..attribute = null
            ..geolocationData.value = gps;
          batch.add(sensorData);
        }
      }
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
