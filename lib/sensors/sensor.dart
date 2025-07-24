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
  final Map<GeolocationData, Map<String, List<List<double>>>> _groupedBuffer =
      {};
  GeolocationData? _lastGeolocation;
  
  // Temporary buffer for sensor data that arrives before first GPS point
  final List<List<double>> _preGpsSensorBuffer = [];

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
      if (_lastGeolocation != null) {
        // Add sensor data to the grouped buffer
        _groupedBuffer.putIfAbsent(_lastGeolocation!, () => {});
        _groupedBuffer[_lastGeolocation!]!.putIfAbsent(title, () => []);
        _groupedBuffer[_lastGeolocation!]![title]!.add(data);
      } else {
        // Store sensor data in temporary buffer until first GPS point arrives
        _preGpsSensorBuffer.add(data);
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
          _lastGeolocation = geo;
          // Flush temporary buffer when GPS point is available
          if (_preGpsSensorBuffer.isNotEmpty) {
            _groupedBuffer.putIfAbsent(_lastGeolocation!, () => {});
            _groupedBuffer[_lastGeolocation!]!.putIfAbsent(title, () => []);
            _groupedBuffer[_lastGeolocation!]![title]!
                .addAll(_preGpsSensorBuffer);
            _preGpsSensorBuffer.clear();
          }
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
    if (_groupedBuffer.isEmpty) {
      return;
    }
    
    final List<SensorData> batch = [];
    
    // Process the grouped data
    for (final entry in _groupedBuffer.entries) {
      final GeolocationData geolocation = entry.key;
      final Map<String, List<List<double>>> sensorData = entry.value;
      
      // Save geolocation if needed
      if (geolocation.id == Isar.autoIncrement || geolocation.id == 0) {
        geolocation.id = await isarService.geolocationService
            .saveGeolocationData(geolocation);
      }
      
      // Process sensor data for this geolocation
      for (final sensorEntry in sensorData.entries) {
        final String sensorTitle = sensorEntry.key;
        final List<List<double>> rawValues = sensorEntry.value;
        
        // Only process data for this specific sensor
        if (sensorTitle == title) {
          // Aggregate the raw values using the sensor's aggregation method
          final List<double> aggregatedValues = aggregateData(rawValues);
          
          // Create sensor data for each attribute
          if (attributes.isNotEmpty) {
            // Multi-value sensor (like finedust, surface_classification)
            for (int j = 0;
                j < attributes.length && j < aggregatedValues.length;
                j++) {
              final sensorData = SensorData()
                ..characteristicUuid = characteristicUuid
                ..title = title
                ..value = aggregatedValues[j]
                ..attribute = attributes[j]
                ..geolocationData.value = geolocation;
              
              batch.add(sensorData);
            }
          } else {
            // Single-value sensor (like temperature, humidity)
            final sensorData = SensorData()
              ..characteristicUuid = characteristicUuid
              ..title = title
              ..value = aggregatedValues.isNotEmpty ? aggregatedValues[0] : 0.0
              ..attribute = null
              ..geolocationData.value = geolocation;
            
            batch.add(sensorData);
          }
        }
      }
    }
    
    // Save sensor data to database
    if (batch.isNotEmpty) {
      await isarService.sensorService.saveSensorDataBatch(batch);
    }
    
    // Send data for direct upload if enabled
    if (_directUploadService != null && recordingBloc.isRecording) {
      // Convert the grouped buffer to the format expected by DirectUploadService
      final Map<GeolocationData, Map<String, List<double>>>
          groupedDataForUpload = {};
      
      for (final entry in _groupedBuffer.entries) {
        final GeolocationData geolocation = entry.key;
        final Map<String, List<List<double>>> sensorData = entry.value;
        
        groupedDataForUpload[geolocation] = {};
        
        for (final sensorEntry in sensorData.entries) {
          final String sensorTitle = sensorEntry.key;
          final List<List<double>> rawValues = sensorEntry.value;
          
          // Aggregate the raw values
          final List<double> aggregatedValues = aggregateData(rawValues);
          groupedDataForUpload[geolocation]![sensorTitle] = aggregatedValues;
        }
      }
      
      final List<GeolocationData> geolocations = List.from(_groupedBuffer.keys);
      _directUploadService!
          .addGroupedDataForUpload(groupedDataForUpload, geolocations);
    }
    
    // Clear the grouped buffer
    _groupedBuffer.clear();
  }

  Widget buildWidget();
  List<double> aggregateData(List<List<double>> valueBuffer);

  void dispose() {
    stopListening();
    _valueController.close();
  }
}
