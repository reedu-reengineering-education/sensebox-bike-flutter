import 'dart:async';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/utils/upload_data_preparer.dart';
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
      // Store raw sensor data without transformation - just store the complete array
      _sensorBuffer.add({
        'timestamp': now,
        'data': data, // Store the complete array instead of individual values
        'sensor': title,
      });
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
    if (_sensorBuffer.isEmpty || _gpsBuffer.isEmpty) {
      return;
    }
    
    // Use the shared grouping logic from UploadDataPreparer
    final groupedData = UploadDataPreparer.groupAndAggregateSensorDataStatic(
        List.from(_sensorBuffer), List.from(_gpsBuffer));
    
    final List<SensorData> batch = [];
    final List<Map<String, dynamic>> processedSensorData = [];

    // Process the grouped data
    for (final entry in groupedData.entries) {
      final GeolocationData geolocation = entry.key;
      final Map<String, List<double>> sensorData = entry.value;
      
      // Save geolocation if needed
      if (geolocation.id == Isar.autoIncrement || geolocation.id == 0) {
        geolocation.id = await isarService.geolocationService
            .saveGeolocationData(geolocation);
      }
      
      // Process sensor data for this geolocation
      for (final sensorEntry in sensorData.entries) {
        final String sensorTitle = sensorEntry.key;
        final List<double> aggregatedValues = sensorEntry.value;
        
        // Only process data for this specific sensor
        if (sensorTitle == title) {
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

    // Mark sensor data as processed for removal
    // We need to find which sensor readings were actually processed
    for (final entry in groupedData.entries) {
      final GeolocationData geolocation = entry.key;
      final Map<String, List<double>> sensorData = entry.value;

      // Only mark as processed if this sensor's data was included
      if (sensorData.containsKey(title)) {
        // Find sensor readings that belong to this geolocation's time range
        final sortedGeolocations = List<GeolocationData>.from(_gpsBuffer)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        final geolocationIndex = sortedGeolocations.indexOf(geolocation);
        if (geolocationIndex >= 0) {
          final currentGeolocationTime = geolocation.timestamp;

          // Determine the time range for this geolocation
          DateTime? startTime;
          DateTime? endTime;

          if (geolocationIndex == 0) {
            startTime = null;
            endTime = currentGeolocationTime;
          } else if (geolocationIndex == sortedGeolocations.length - 1) {
            final previousGeolocationTime =
                sortedGeolocations[geolocationIndex - 1].timestamp;
            startTime = previousGeolocationTime;
            endTime = null;
          } else {
            final previousGeolocationTime =
                sortedGeolocations[geolocationIndex - 1].timestamp;
            startTime = previousGeolocationTime;
            endTime = currentGeolocationTime;
          }

          // Find sensor readings in this time range
          for (final reading in _sensorBuffer) {
            final DateTime readingTime = reading['timestamp'] as DateTime;
            final String readingSensorTitle = reading['sensor'] as String;

            if (readingSensorTitle == title) {
              bool isInRange = true;
              if (startTime != null && readingTime.isBefore(startTime)) {
                isInRange = false;
              }
              if (endTime != null && readingTime.isAfter(endTime)) {
                isInRange = false;
              }

              if (isInRange) {
                processedSensorData.add(reading);
              }
            }
          }
        }
      }
    }

    // Save aggregated data to database
    if (batch.isNotEmpty) {
      await isarService.sensorService.saveSensorDataBatch(batch);
    }
    
    // Remove processed sensor data from buffer
    for (final processed in processedSensorData) {
      _sensorBuffer.remove(processed);
    }

    // Send data for direct upload if enabled (before clearing GPS buffer)
    if (_directUploadService != null && recordingBloc.isRecording) {
      _directUploadService!
          .addGroupedDataForUpload(groupedData, List.from(_gpsBuffer));
    }

    // Clear GPS buffer (all geolocations have been processed)
    _gpsBuffer.clear();
  }

  Widget buildWidget();
  List<double> aggregateData(List<List<double>> valueBuffer);

  void dispose() {
    stopListening();
    _valueController.close();
  }
}
