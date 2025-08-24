import 'dart:async';
import 'dart:convert';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/utils/geo_utils.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:turf/turf.dart' as Turf;
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

abstract class Sensor {
  final String characteristicUuid;
  final String title;
  final List<String> attributes;
  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final SettingsBloc settingsBloc;
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
  bool _isFlushing = false;
  final Set<int> _processedGeolocationIds = {};
  final Set<int> _uploadedGeolocationIds = {}; 

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
    
    uploadService.setUploadSuccessCallback((uploadedGpsPoints) {
      for (final gpsPoint in uploadedGpsPoints) {
        _uploadedGeolocationIds.add(gpsPoint.id);
      }

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

    uploadService.setPermanentDisableCallback(() {
      // Don't clear sensor buffers - just clear upload tracking
      // This allows local data collection to continue even when uploads are disabled
      _uploadedGeolocationIds.clear();
      // Keep _groupedBuffer and _processedGeolocationIds for local persistence

    });
  }

  void onDataReceived(List<double> data) {
    if (data.isNotEmpty && recordingBloc.isRecording) {
      // Always buffer data for local persistence, regardless of upload service status
      // This ensures data is collected locally even when uploads are disabled
      if (_lastGeolocation != null) {
        _groupedBuffer.putIfAbsent(_lastGeolocation!, () => {});
        _groupedBuffer[_lastGeolocation!]!.putIfAbsent(title, () => []);
        _groupedBuffer[_lastGeolocation!]![title]!.add(data);
      } else {
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
        _lastGeolocation = geo;

        // Process any deferred data when GPS becomes available
        if (_directUploadService != null &&
            _directUploadService!.hasDeferredData) {
          _directUploadService!.onGpsAvailable(geo);
        }

        if (_preGpsSensorBuffer.isNotEmpty) {
          _groupedBuffer.putIfAbsent(_lastGeolocation!, () => {});
          _groupedBuffer[_lastGeolocation!]!
              .putIfAbsent(title, () => <List<double>>[]);
          _groupedBuffer[_lastGeolocation!]![title]!
              .addAll(_preGpsSensorBuffer);

          _preGpsSensorBuffer.clear();
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

  void clearBuffersOnRecordingStop() {
    if (!recordingBloc.isRecording) {
      _groupedBuffer.clear();
      _processedGeolocationIds.clear();
    }
  }

  void clearBuffersForNewRecording() {
    _groupedBuffer.clear();
    _processedGeolocationIds.clear();
  }





  Future<void> _flushBuffers() async {
    if (_groupedBuffer.isEmpty) {
      return;
    }

    // Always process and save data locally, regardless of upload service status
    // Uploads are attempted only when the service is available and enabled
    if (_isFlushing) {
      return;
    }
    _isFlushing = true;

    try {
      // Create a copy of entries to avoid concurrent modification
      final bufferCopy =
          Map<GeolocationData, Map<String, List<List<double>>>>.from(
              _groupedBuffer);
      
      final List<SensorData> batch = [];
      final Set<int> processedInThisFlush = {};
      final Map<GeolocationData, Map<String, List<double>>>
          groupedDataForUpload = {};
      final List<GeolocationData> geolocationsForUpload = [];
      final int maxBatchSize = 100;
      int processedCount = 0;

      for (final entry in bufferCopy.entries) {
        if (processedCount >= maxBatchSize) {
          break;
        }
        
        final GeolocationData geolocation = entry.key;
        final Map<String, List<List<double>>> sensorData = entry.value;

        if (_processedGeolocationIds.contains(geolocation.id)) {
          continue;
        }

        // Save GPS point with privacy zone checking if not already saved
        if (geolocation.id == Isar.autoIncrement || geolocation.id == 0) {
          try {
            // Check privacy zones before saving
            final privacyZones = settingsBloc.privacyZones
                .map((e) => Turf.Polygon.fromJson(jsonDecode(e)));
            bool isInZone = isInsidePrivacyZone(privacyZones, geolocation);

            if (!isInZone) {
              // Save the geolocation data and get the assigned ID
              final savedId = await isarService.geolocationService
                  .saveGeolocationData(geolocation);
              geolocation.id = savedId;
              
              // Create and save GPS speed as SensorData for consistent UI display
              final gpsSpeedSensorData = createGpsSpeedSensorData(geolocation);
              if (shouldStoreSensorData(gpsSpeedSensorData)) {
                await isarService.sensorService
                    .saveSensorData(gpsSpeedSensorData);
              }
            } else {
              // Skip this GPS point if it's in a privacy zone
              continue;
            }
          } catch (e) {
            debugPrint('Error saving geolocation data: $e');
            continue;
          }
        }

        for (final sensorEntry in sensorData.entries) {
          final String sensorTitle = sensorEntry.key;
          final List<List<double>> rawValues = sensorEntry.value;

          if (sensorTitle == title) {
            final List<double> aggregatedValues = aggregateData(rawValues);
            
            groupedDataForUpload[geolocation] = {sensorTitle: aggregatedValues};
            geolocationsForUpload.add(geolocation);

            if (attributes.isNotEmpty) {
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
        processedCount++;
      }

      if (batch.isNotEmpty) {
        try {
          await isarService.sensorService.saveSensorDataBatch(batch);
        } catch (e) {
          return; // Don't clear buffer on save failure
        }
      }

      // Only attempt upload if service is available and uploads are enabled
      if (_directUploadService != null &&
          recordingBloc.isRecording &&
          groupedDataForUpload.isNotEmpty &&
          !_directUploadService!.isUploadDisabled) {
        _directUploadService!.addGroupedDataForUpload(
            groupedDataForUpload, geolocationsForUpload);
      } else if (_directUploadService != null &&
          recordingBloc.isRecording &&
          groupedDataForUpload.isNotEmpty) {
        // GPS unavailable - store data for deferred upload
        _storeDataForDeferredUpload(groupedDataForUpload);
      }
      // Note: Buffer clearing is now handled by upload success callback
      // This prevents data loss when recording stops but upload fails
    } catch (e) {
      debugPrint('Error in _flushBuffers for sensor $title: $e');
    } finally {
      _isFlushing = false;
    }
  }

  Widget buildWidget();
  
  /// Stores sensor data for deferred upload when GPS is unavailable
  void _storeDataForDeferredUpload(
      Map<GeolocationData, Map<String, List<double>>> groupedData) {
    if (_directUploadService == null) return;

    for (final entry in groupedData.entries) {
      final sensorData = entry.value;
      for (final sensorEntry in sensorData.entries) {
        final sensorTitle = sensorEntry.key;
        final values = sensorEntry.value;

        // Store in deferred buffer for later upload
        _directUploadService!.addDeferredSensorData(sensorTitle, values);
      }
    }

    debugPrint(
        '[Sensor] Stored ${groupedData.length} sensor data entries for deferred upload (GPS unavailable)');
  }
  
  void dispose() {
    stopListening();
    _valueController.close();
  }
}
