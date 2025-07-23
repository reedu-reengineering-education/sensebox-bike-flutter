// File: lib/blocs/sensor_bloc.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/sensors/acceleration_sensor.dart';
import 'package:sensebox_bike/sensors/distance_sensor.dart';
import 'package:sensebox_bike/sensors/finedust_sensor.dart';
import 'package:sensebox_bike/sensors/gps_sensor.dart';
import 'package:sensebox_bike/sensors/humidity_sensor.dart';
import 'package:sensebox_bike/sensors/overtaking_prediction_sensor.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/sensors/surface_anomaly_sensor.dart';
import 'package:sensebox_bike/sensors/surface_classification_sensor.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';

class SensorBloc with ChangeNotifier {
  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final List<Sensor> _sensors = [];
  late final VoidCallback _characteristicsListener;
  late final VoidCallback _characteristicStreamsVersionListener;
  late final VoidCallback _selectedDeviceListener;
  late final VoidCallback _recordingListener;
  List<String> _lastCharacteristicUuids = [];

  SensorBloc(this.bleBloc, this.geolocationBloc, this.recordingBloc) {
    _initializeSensors();

    // Listen to changes in the BLE device connection state
    _selectedDeviceListener = () {
      if (bleBloc.selectedDevice != null &&
          bleBloc.selectedDevice!.isConnected) {
        _startListening();
        geolocationBloc.startListening();
      } else {
        _stopListening();
        geolocationBloc.stopListening();
      }
      notifyListeners();
    };

    // Listen to changes in available characteristics
    _characteristicsListener = () {
      final currentUuids = bleBloc.availableCharacteristics.value
          .map((e) => e.uuid.toString())
          .toList();
      if (!_listEqualsUnordered(_lastCharacteristicUuids, currentUuids)) {
        _lastCharacteristicUuids = List.from(currentUuids);
        _restartAllSensors();
      }
    };

    // Listen to changes in characteristic streams version
    _characteristicStreamsVersionListener = () {
      _restartAllSensors();
    };

    // Listen to recording state changes
    _recordingListener = () {
      if (!recordingBloc.isRecording) {
        debugPrint('Recording stopped, flushing all sensor buffers');
        _flushAllSensorBuffers();
      }
    };
    recordingBloc.isRecordingNotifier.addListener(_recordingListener!);

    // Set up recording callbacks to avoid circular dependency
    recordingBloc.setRecordingCallbacks(
      onRecordingStart: _onRecordingStart,
      onRecordingStop: _onRecordingStop,
    );

    // Add listeners
    bleBloc.selectedDeviceNotifier.addListener(_selectedDeviceListener);
    bleBloc.availableCharacteristics.addListener(_characteristicsListener);
    bleBloc.characteristicStreamsVersion
        .addListener(_characteristicStreamsVersionListener);
  }

  /// Callback when recording starts - set up direct upload for all sensors
  void _onRecordingStart() {
    final directUploadService = recordingBloc.directUploadService;
    if (directUploadService != null) {
      // Set the upload service for all sensors
      for (final sensor in _sensors) {
        sensor.setDirectUploadService(directUploadService);
      }

      // Enable direct upload mode
      directUploadService.enable();
      debugPrint('SensorBloc: Direct upload mode enabled for all sensors');
    }
  }

  /// Callback when recording stops - clean up direct upload
  Future<void> _onRecordingStop() async {
    final directUploadService = recordingBloc.directUploadService;
    if (directUploadService != null) {
      // Upload any remaining buffered data
      await directUploadService.uploadRemainingBufferedData();

      // Disable direct upload mode
      directUploadService.disable();
      debugPrint('SensorBloc: Direct upload mode disabled for all sensors');
    }
  }

  bool _listEqualsUnordered(List<String> a, List<String> b) {
    final aSorted = List<String>.from(a)..sort();
    final bSorted = List<String>.from(b)..sort();
    return aSorted.length == bSorted.length &&
        aSorted.every((element) => bSorted.contains(element));
  }

  void _initializeSensors() {
    final isarService = geolocationBloc.isarService;
    // Initialize sensors with specific UUIDs
    _sensors.add(TemperatureSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(
        HumiditySensor(bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(
        DistanceSensor(bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(SurfaceClassificationSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(AccelerationSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(OvertakingPredictionSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(SurfaceAnomalySensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(
        FinedustSensor(bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors
        .add(GPSSensor(bleBloc, geolocationBloc, recordingBloc, isarService));
  }

  void _startListening() {
    for (var sensor in _sensors) {
      sensor.startListening();
    }
  }

  void _stopListening() {
    for (var sensor in _sensors) {
      sensor.stopListening();
    }
  }

  void _restartAllSensors() {
    _stopListening();
    _startListening();
  }

  /// Flush all sensor buffers - useful for immediate saving when recording stops
  Future<void> _flushAllSensorBuffers() async {
    for (var sensor in _sensors) {
      await sensor.flushBuffers();
    }
  }

  List<Sensor> get sensors => _sensors;

  List<Widget> getSensorWidgets() {
    final availableUuids = bleBloc.availableCharacteristics.value
        .map((e) => e.uuid.toString())
        .toSet();

    final availableSensors = _sensors.where((sensor) {
      // Filter out surface_anomaly if the feature flag is enabled
      if (FeatureFlags.hideSurfaceAnomalySensor &&
          sensor.title == 'surface_anomaly') {
        return false;
      }
      return availableUuids.contains(sensor.characteristicUuid);
    }).toList();

    availableSensors.sort((a, b) => a.uiPriority.compareTo(b.uiPriority));
    return availableSensors.map((sensor) => sensor.buildWidget()).toList();
  }

  @override
  void dispose() {
    // Remove all listeners
    bleBloc.selectedDeviceNotifier.removeListener(_selectedDeviceListener);
    bleBloc.availableCharacteristics.removeListener(_characteristicsListener);
    bleBloc.characteristicStreamsVersion
        .removeListener(_characteristicStreamsVersionListener);
    recordingBloc.isRecordingNotifier.removeListener(_recordingListener);
    
    _stopListening();
    
    // Dispose all sensors
    for (final sensor in _sensors) {
      sensor.dispose();
    }
    
    super.dispose();
  }
}
