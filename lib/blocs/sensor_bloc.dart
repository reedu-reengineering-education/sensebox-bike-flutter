// File: lib/blocs/sensor_bloc.dart
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
import 'package:flutter/material.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';

class SensorBloc with ChangeNotifier {
  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final RecordingBloc recordingBloc;
  final List<Sensor> _sensors = [];
  late final VoidCallback _characteristicsListener;
  late final VoidCallback _characteristicStreamsVersionListener;
  late final VoidCallback _selectedDeviceListener;
  List<String> _lastCharacteristicUuids = [];

  SensorBloc(this.bleBloc, this.geolocationBloc, this.recordingBloc) {
    _initializeSensors();

    // Listen to changes in the BLE device connection state
    _selectedDeviceListener = () {
      debugPrint(
          'Selected device changed: ${bleBloc.selectedDevice?.platformName}');
      if (bleBloc.selectedDevice != null &&
          bleBloc.selectedDevice!.isConnected) {
        debugPrint('Device connected, starting sensors and geolocation');
        _startListening();
        geolocationBloc.startListening();
      } else {
        debugPrint('Device disconnected, stopping sensors and geolocation');
        _stopListening();
        geolocationBloc.stopListening();
      }
    };

    bleBloc.selectedDeviceNotifier.addListener(_selectedDeviceListener);

    // Listen to changes in available characteristics (after reconnect)
    _characteristicsListener = () {
      debugPrint('Available characteristics changed');
      if (bleBloc.selectedDevice != null &&
          bleBloc.selectedDevice!.isConnected) {
        final currentUuids = bleBloc.availableCharacteristics.value
            .map((e) => e.uuid.toString())
            .toList();

        debugPrint('Current UUIDs: $currentUuids');
        debugPrint('Last UUIDs: $_lastCharacteristicUuids');

        // Only restart if the set of UUIDs has changed
        if (!_listEqualsUnordered(_lastCharacteristicUuids, currentUuids)) {
          debugPrint('UUIDs changed, restarting sensors');
          _lastCharacteristicUuids = List.from(currentUuids);
          _restartAllSensors();
        } else {
          debugPrint('UUIDs unchanged, not restarting sensors');
        }
      }
    };
    bleBloc.availableCharacteristics.addListener(_characteristicsListener);

    // Listen for characteristic stream version changes (after reconnect)
    _characteristicStreamsVersionListener = () {
      debugPrint('Characteristic stream version changed, restarting sensors');
      _restartAllSensors();
    };
    bleBloc.characteristicStreamsVersion
        .addListener(_characteristicStreamsVersionListener);
  }

  bool _listEqualsUnordered(List<String> a, List<String> b) {
    final aSorted = List<String>.from(a)..sort();
    final bSorted = List<String>.from(b)..sort();
    return aSorted.length == bSorted.length &&
        aSorted.every((element) => bSorted.contains(element));
  }

  void _initializeSensors() {
    debugPrint('Initializing sensors');
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
    _sensors
        .add(OvertakingPredictionSensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(SurfaceAnomalySensor(
        bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors.add(
        FinedustSensor(bleBloc, geolocationBloc, recordingBloc, isarService));
    _sensors
        .add(GPSSensor(bleBloc, geolocationBloc, recordingBloc, isarService));
    debugPrint('Initialized ${_sensors.length} sensors');
  }

  void _startListening() {
    debugPrint('Starting to listen to ${_sensors.length} sensors');
    for (var sensor in _sensors) {
      debugPrint(
          'Starting sensor: ${sensor.title} with UUID: ${sensor.characteristicUuid}');
      sensor.startListening();
    }
  }

  void _stopListening() {
    debugPrint('Stopping all sensors');
    for (var sensor in _sensors) {
      sensor.stopListening();
    }
  }

  void _restartAllSensors() {
    debugPrint('Restarting all sensors');
    _stopListening();
    _startListening();
  }

  List<Widget> getSensorWidgets() {
    final availableUuids = bleBloc.availableCharacteristics.value
        .map((e) => e.uuid.toString())
        .toSet();
    
    debugPrint('Available UUIDs: $availableUuids');
    debugPrint('Total sensors: ${_sensors.length}');

    final availableSensors = _sensors.where((sensor) {
      if (FeatureFlags.hideSurfaceAnomalySensor &&
          sensor is SurfaceAnomalySensor) {
        debugPrint('Filtering out SurfaceAnomalySensor due to feature flag');
        return false;
      }
      final isAvailable = availableUuids.contains(sensor.characteristicUuid);
      debugPrint(
          'Sensor ${sensor.title} (${sensor.characteristicUuid}): ${isAvailable ? 'available' : 'not available'}');
      return isAvailable;
    }).toList();

    debugPrint('Available sensors: ${availableSensors.length}');
    availableSensors.sort((a, b) => a.uiPriority.compareTo(b.uiPriority));
    return availableSensors.map((sensor) => sensor.buildWidget()).toList();
  }

  @override
  void dispose() {
    for (var sensor in _sensors) {
      sensor.dispose();
    }

    bleBloc.selectedDeviceNotifier.removeListener(_selectedDeviceListener);
    bleBloc.availableCharacteristics.removeListener(_characteristicsListener);
    bleBloc.characteristicStreamsVersion
        .removeListener(_characteristicStreamsVersionListener);
        
    super.dispose();
  }
}
