// File: lib/blocs/sensor_bloc.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
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
  final SettingsBloc settingsBloc;
  final List<Sensor> _sensors = [];
  late final VoidCallback _characteristicsListener;
  late final VoidCallback _characteristicStreamsVersionListener;
  late final VoidCallback _selectedDeviceListener;
  late final VoidCallback _recordingListener;
  List<String> _lastCharacteristicUuids = [];

  SensorBloc(this.bleBloc, this.geolocationBloc, this.recordingBloc,
      this.settingsBloc) {
    _initializeSensors();

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

    _characteristicsListener = () {
      final currentUuids = bleBloc.availableCharacteristics.value
          .map((e) => e.uuid.toString())
          .toList();
      if (!_listEqualsUnordered(_lastCharacteristicUuids, currentUuids)) {
        _lastCharacteristicUuids = List.from(currentUuids);
        _restartAllSensors();
      }
    };

    _characteristicStreamsVersionListener = () {
      _restartAllSensors();
    };

    _recordingListener = () {
      if (!recordingBloc.isRecording) {
        _flushAllSensorBuffers();
      }
    };
    recordingBloc.isRecordingNotifier.addListener(_recordingListener);
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

  void _onRecordingStart() {
    _clearAllSensorBuffersForNewRecording();
    
    final directUploadService = recordingBloc.directUploadService;
    if (directUploadService != null) {

      for (final sensor in _sensors) {
        sensor.setDirectUploadService(directUploadService);
      }

      directUploadService.enable();
    }
    
    geolocationBloc.startListening();
    geolocationBloc.getCurrentLocationAndEmit().catchError((e) {
      debugPrint('Failed to get initial GPS location: $e');
    });
  }

  Future<void> _onRecordingStop() async {
    final directUploadService = recordingBloc.directUploadService;
    if (directUploadService != null) {
      await directUploadService.uploadRemainingBufferedData();

      for (var sensor in _sensors) {
        sensor.clearBuffersOnRecordingStop();
      }

      directUploadService.disable();

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

    _sensors.add(TemperatureSensor(
        bleBloc, geolocationBloc, recordingBloc, settingsBloc, isarService));
    _sensors.add(
        HumiditySensor(
        bleBloc, geolocationBloc, recordingBloc, settingsBloc, isarService));
    _sensors.add(
        DistanceSensor(
        bleBloc, geolocationBloc, recordingBloc, settingsBloc, isarService));
    _sensors.add(SurfaceClassificationSensor(
        bleBloc, geolocationBloc, recordingBloc, settingsBloc, isarService));
    _sensors.add(AccelerationSensor(
        bleBloc, geolocationBloc, recordingBloc, settingsBloc, isarService));
    _sensors.add(OvertakingPredictionSensor(
        bleBloc, geolocationBloc, recordingBloc, settingsBloc, isarService));
    _sensors.add(SurfaceAnomalySensor(
        bleBloc, geolocationBloc, recordingBloc, settingsBloc, isarService));
    _sensors.add(
        FinedustSensor(
        bleBloc, geolocationBloc, recordingBloc, settingsBloc, isarService));
    _sensors
        .add(GPSSensor(
        bleBloc, geolocationBloc, recordingBloc, settingsBloc, isarService));
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

  Future<void> _flushAllSensorBuffers() async {
    for (var sensor in _sensors) {
      await sensor.flushBuffers();
    }
  }

  void _clearAllSensorBuffersForNewRecording() {
    for (var sensor in _sensors) {
      sensor.clearBuffersForNewRecording();
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
    bleBloc.selectedDeviceNotifier.removeListener(_selectedDeviceListener);
    bleBloc.availableCharacteristics.removeListener(_characteristicsListener);
    bleBloc.characteristicStreamsVersion
        .removeListener(_characteristicStreamsVersionListener);
    recordingBloc.isRecordingNotifier.removeListener(_recordingListener);
    
    _stopListening();
    
    for (final sensor in _sensors) {
      sensor.dispose();
    }
    
    super.dispose();
  }
}
