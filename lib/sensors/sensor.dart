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
        if (_groupedBuffer.length > 100) {
          debugPrint('Sensor $title: Buffer size exceeded 50, forcing flush');
          // Use unawaited to prevent blocking the main thread
          _flushBuffers().catchError((e) {
            debugPrint(
                'Error during forced buffer flush for sensor $title: $e');
          });
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

    // Add timeout protection to prevent hanging operations
    final timeoutDuration = Duration(seconds: 30);
    
    try {
      final List<SensorData> batch = [];
      final Set<int> processedInThisFlush =
          {}; // Track geolocations processed in this flush

      // Limit batch size to prevent memory spikes
      final int maxBatchSize = 200; // Limit to prevent excessive memory usage
      int processedCount = 0;

      // Process the grouped data
      for (final entry in _groupedBuffer.entries) {
        // Stop processing if batch size limit reached
        if (processedCount >= maxBatchSize) {
          debugPrint('Sensor $title: Batch size limit reached (${maxBatchSize}), stopping processing');
          break;
        }
        final GeolocationData geolocation = entry.key;
        final Map<String, List<List<double>>> sensorData = entry.value;

        if (!_processedGeolocationIds.contains(geolocation.id)) {
          // Ensure GPS point is saved to database before linking SensorData
          if (geolocation.id == Isar.autoIncrement || geolocation.id == 0) {
            try {
              final savedId = await isarService.geolocationService
                  .saveGeolocationData(geolocation);
              
              // Update the original GPS object with the saved ID
              geolocation.id = savedId;
            } catch (e) {
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
          processedCount++;
        }
      }

      // Save sensor data to database with better error handling and timeout protection
      if (batch.isNotEmpty) {
        try {
          await isarService.sensorService
              .saveSensorDataBatch(batch)
              .timeout(timeoutDuration);
        } catch (e) {
          debugPrint(
              'Failed to save sensor data batch for sensor $title: $e. Batch size: ${batch.length}');
          // Don't clear buffer on save failure - data will be retried
          // But limit the buffer size to prevent memory issues
          if (_groupedBuffer.length > 100) {
            debugPrint(
                'Sensor $title: Buffer too large after save failure, clearing oldest entries');
            final entriesToRemove = _groupedBuffer.entries
                .take(_groupedBuffer.length - 50)
                .toList();
            for (final entry in entriesToRemove) {
              _groupedBuffer.remove(entry.key);
            }
          }
          return;
        }
      }

      // Send data for direct upload if enabled - reuse already processed data
      if (_directUploadService != null && recordingBloc.isRecording) {
        // Create upload data from already processed entries to avoid double processing
        final Map<GeolocationData, Map<String, List<double>>> groupedDataForUpload = {};
        final List<GeolocationData> geolocations = [];

        // Only process entries that were successfully saved to database
        for (final entry in _groupedBuffer.entries) {
          final GeolocationData geolocation = entry.key;
          final Map<String, List<List<double>>> sensorData = entry.value;

          // Only include GPS points that were processed in this flush
          if (processedInThisFlush.contains(geolocation.id)) {
            groupedDataForUpload[geolocation] = {};
            geolocations.add(geolocation);

            for (final sensorEntry in sensorData.entries) {
              final String sensorTitle = sensorEntry.key;
              final List<List<double>> rawValues = sensorEntry.value;

              if (sensorTitle == title) {
                // Reuse the aggregated values that were already calculated for database
                // This avoids calling aggregateData() twice for the same data
                final List<double> aggregatedValues = aggregateData(rawValues);
                groupedDataForUpload[geolocation]![sensorTitle] = aggregatedValues;
              }
            }
          }
        }

        if (_directUploadService!.isEnabled && groupedDataForUpload.isNotEmpty) {
          final bool dataAdded = _directUploadService!
              .addGroupedDataForUpload(groupedDataForUpload, geolocations);
          
          // Don't clear buffer here - it will be cleared via upload success callback
          // This ensures data is preserved if upload fails
        }
      } else {
        // Clear buffer if no upload service available or not recording
        _groupedBuffer.clear();
      }
    } catch (e) {
      debugPrint('Error in _flushBuffers for sensor $title: $e');
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
