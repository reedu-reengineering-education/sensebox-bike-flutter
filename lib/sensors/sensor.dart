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
  final Set<int> _uploadedGeolocationIds = {}; // Track uploaded geolocation IDs

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
    
    // Set up upload success callback to clear successfully uploaded GPS points
    uploadService.setUploadSuccessCallback((uploadedGpsPoints) {
      for (final gpsPoint in uploadedGpsPoints) {
        _uploadedGeolocationIds.add(gpsPoint.id);
      }

      // Clear GPS points that have been successfully uploaded
      final List<GeolocationData> pointsToRemove = [];
      for (final entry in _groupedBuffer.entries) {
        if (_uploadedGeolocationIds.contains(entry.key.id)) {
          pointsToRemove.add(entry.key);
        }
      }

      for (final point in pointsToRemove) {
        _groupedBuffer.remove(point);
      }
    });
  }

  void onDataReceived(List<double> data) {
    if (data.isNotEmpty && recordingBloc.isRecording) {
      if (_lastGeolocation != null) {
        // Add sensor data to the grouped buffer
        _groupedBuffer.putIfAbsent(_lastGeolocation!, () => {});
        _groupedBuffer[_lastGeolocation!]!.putIfAbsent(title, () => []);
        _groupedBuffer[_lastGeolocation!]![title]!.add(data);
        
        // Force flush if buffer gets too large to prevent memory issues
        if (_groupedBuffer.length > 1000) {
          debugPrint('Sensor $title: Buffer size exceeded 50, forcing flush');
          _flushBuffers();
        }
      } else {
        // Store sensor data in temporary buffer until first GPS point arrives
        _preGpsSensorBuffer.add(data);
        
        // Log when sensor data is buffered without GPS
        if (_preGpsSensorBuffer.length % 10 == 0) {
          // Log every 10th buffer entry
          print(
              'Sensor $title: ${_preGpsSensorBuffer.length} data points buffered without GPS location');
        }
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
            
            // Log when pre-GPS buffer is flushed
            print(
                'Sensor $title: Flushed ${_preGpsSensorBuffer.length} pre-GPS data points to GPS location ${geo.latitude}, ${geo.longitude}');
                
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

    // Check for any remaining buffered data before stopping
    if (_preGpsSensorBuffer.isNotEmpty) {
      print(
          'Sensor $title: ${_preGpsSensorBuffer.length} pre-GPS data points remaining when stopping');
    }
    if (_groupedBuffer.isNotEmpty) {
      print(
          'Sensor $title: ${_groupedBuffer.length} GPS points with buffered data remaining when stopping');
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

        // Process sensor data for database only if we haven't already processed this geolocation
        // If GPS point doesn't have a valid ID, save it to database first
        if (!_processedGeolocationIds.contains(geolocation.id)) {
          // Ensure GPS point is saved to database before linking SensorData
          if (geolocation.id == Isar.autoIncrement || geolocation.id == 0) {
            try {
              final savedId = await isarService.geolocationService
                  .saveGeolocationData(geolocation);
              
              // Update the original GPS object with the saved ID
              geolocation.id = savedId;
            } catch (e) {
              // Log the error but don't skip the GPS point - try to save sensor data anyway
              print(
                  'Failed to save GPS point for sensor data: $e. GPS: ${geolocation.latitude}, ${geolocation.longitude}, ${geolocation.timestamp}');
              // Don't continue here - try to save sensor data even if GPS save failed
            }
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

          // Track processed geolocations to prevent duplicates
          processedInThisFlush.add(geolocation.id);
          _processedGeolocationIds.add(geolocation.id);
        }
      }

      // Save sensor data to database with better error handling
      if (batch.isNotEmpty) {
        try {
          await isarService.sensorService.saveSensorDataBatch(batch);
          print(
              'Successfully saved ${batch.length} sensor data points for sensor $title');
        } catch (e) {
          print(
              'Failed to save sensor data batch for sensor $title: $e. Batch size: ${batch.length}');
          // Don't clear buffer on save failure - data will be retried
          return;
        }
      }

      // Send data for direct upload if enabled - use grouped buffer data directly
      if (_directUploadService != null && recordingBloc.isRecording) {
        // Convert the grouped buffer data directly to the format expected by DirectUploadService
        final Map<GeolocationData, Map<String, List<double>>>
            groupedDataForUpload = {};
        final List<GeolocationData> processedGeolocations = [];

        // Process the grouped buffer data directly
        for (final entry in _groupedBuffer.entries) {
          final GeolocationData geolocation = entry.key;
          final Map<String, List<List<double>>> sensorData = entry.value;

          // Include all GPS points in upload data, regardless of database ID status
          // This ensures no sensor data is lost due to GPS filtering or database delays
          groupedDataForUpload[geolocation] = {};

          for (final sensorEntry in sensorData.entries) {
            final String sensorTitle = sensorEntry.key;
            final List<List<double>> rawValues = sensorEntry.value;

            // Process data for this specific sensor
            if (sensorTitle == title) {
              // Aggregate the raw values using the sensor's aggregation method
              final List<double> aggregatedValues = aggregateData(rawValues);
              groupedDataForUpload[geolocation]![sensorTitle] =
                  aggregatedValues;


            }
          }
          
          // Track which GPS points have been processed for upload
          processedGeolocations.add(geolocation);
        }

        final List<GeolocationData> geolocations = groupedDataForUpload.keys.toList();
        
        // Only send data if DirectUploadService is enabled
        if (_directUploadService!.isEnabled) {
          final bool dataAdded = _directUploadService!
              .addGroupedDataForUpload(groupedDataForUpload, geolocations);
          
          // Don't clear buffer here - it will be cleared via upload success callback
          // This ensures data is preserved if upload fails
        } else {
          // Keep buffer data if upload service is disabled (e.g., due to connectivity issues)
          // Data will be retried on next flush when service is re-enabled
        }
      } else {
        // Clear buffer if no upload service available or not recording
        _groupedBuffer.clear();
      }
    } catch (e) {
      print('Error in _flushBuffers for sensor $title: $e');
    } finally {
      // Only reset flushing flag, don't clear buffer here
      _isFlushing = false;
    }
  }

  Widget buildWidget();
  void dispose() {
    stopListening();
    _valueController.close();
  }
}
