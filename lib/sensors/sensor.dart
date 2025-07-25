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

  StreamController<List<double>> _valueController =
      StreamController<List<double>>.broadcast();
  StreamSubscription<List<double>>? _subscription;
  Timer? _batchTimer;
  final Duration _batchTimeout = Duration(seconds: 5);
  final Map<GeolocationData, Map<String, List<List<double>>>> _groupedBuffer =
      {};
  final List<List<double>> _preGpsSensorBuffer = [];
  GeolocationData? _lastGeolocation;
  DirectUploadService? _directUploadService;
  VoidCallback? _recordingListener;
  bool _isFlushing = false; // Add flag to prevent multiple simultaneous flushes
  final Set<int> _processedGeolocationIds =
      {}; // Track processed geolocation IDs

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
    
    // Prevent multiple simultaneous flushes
    if (_isFlushing) {
      return;
    }
    _isFlushing = true;

    try {
      final List<SensorData> batch = [];
      final Set<int> processedInThisFlush =
          {}; // Track geolocations processed in this flush

      // Process the grouped data
      for (final entry in _groupedBuffer.entries) {
        final GeolocationData geolocation = entry.key;
        final Map<String, List<List<double>>> sensorData = entry.value;

        // Skip if geolocation doesn't have an ID (not saved by GeolocationBloc yet)
        if (geolocation.id == Isar.autoIncrement || geolocation.id == 0) {
          continue; // Skip this geolocation until it's saved by GeolocationBloc
        }

        // Skip if this geolocation has already been processed in this flush
        if (processedInThisFlush.contains(geolocation.id)) {
          continue;
        }

        // Skip if this geolocation has already been processed in a previous flush
        if (_processedGeolocationIds.contains(geolocation.id)) {
          continue;
        }

        // Process sensor data for this geolocation
        for (final sensorEntry in sensorData.entries) {
          final String sensorTitle = sensorEntry.key;
          final List<List<double>> rawValues = sensorEntry.value;

          if (sensorTitle == title) {
            final List<double> aggregatedValues = aggregateData(rawValues);
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
                ..value =
                    aggregatedValues.isNotEmpty ? aggregatedValues[0] : 0.0
                ..attribute = null
                ..geolocationData.value = geolocation;

              batch.add(sensorData);
            }
          }
        }

        processedInThisFlush.add(geolocation.id);
        _processedGeolocationIds.add(geolocation.id);
      }

      // Save sensor data to database
      if (batch.isNotEmpty) {
        await isarService.sensorService.saveSensorDataBatch(batch);
      }

      // Send data for direct upload if enabled - use grouped buffer data directly
      if (_directUploadService != null && recordingBloc.isRecording) {
        // Convert the grouped buffer data directly to the format expected by DirectUploadService
        final Map<GeolocationData, Map<String, List<double>>>
            groupedDataForUpload = {};

        // Process the grouped buffer data directly
        for (final entry in _groupedBuffer.entries) {
          final GeolocationData geolocation = entry.key;
          final Map<String, List<List<double>>> sensorData = entry.value;

          // Skip if geolocation doesn't have an ID (same logic as above)
          if (geolocation.id == Isar.autoIncrement || geolocation.id == 0) {
            continue;
          }

          groupedDataForUpload[geolocation] = {};

          for (final sensorEntry in sensorData.entries) {
            final String sensorTitle = sensorEntry.key;
            final List<List<double>> rawValues = sensorEntry.value;

            // Only process data for this specific sensor
            if (sensorTitle == title) {
              // Aggregate the raw values using the sensor's aggregation method
              final List<double> aggregatedValues = aggregateData(rawValues);
              groupedDataForUpload[geolocation]![sensorTitle] =
                  aggregatedValues;
            }
          }
        }

        final List<GeolocationData> geolocations =
            groupedDataForUpload.keys.toList();
        _directUploadService!
            .addGroupedDataForUpload(groupedDataForUpload, geolocations);
      }
    } finally {
      // Always clear the grouped buffer, even if an error occurred
      _groupedBuffer.clear();
      _isFlushing = false;
    }
  }

  Widget buildWidget();
  void dispose() {
    stopListening();
    _valueController.close();
  }
}
