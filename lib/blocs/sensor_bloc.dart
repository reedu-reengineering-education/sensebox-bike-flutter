// File: lib/blocs/sensor_bloc.dart
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
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
  final List<Sensor> _sensors = [];
  late final VoidCallback _characteristicsListener;
  late final VoidCallback _characteristicStreamsVersionListener;
  late final VoidCallback _selectedDeviceListener;
  List<String> _lastCharacteristicUuids = [];

  SensorBloc(this.bleBloc, this.geolocationBloc) {
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
    };

    bleBloc.selectedDeviceNotifier.addListener(_selectedDeviceListener);

    // Listen to changes in available characteristics (after reconnect)
    _characteristicsListener = () {
      if (bleBloc.selectedDevice != null &&
          bleBloc.selectedDevice!.isConnected) {
        final currentUuids = bleBloc.availableCharacteristics.value
            .map((e) => e.uuid.toString())
            .toList();

        // Only restart if the set of UUIDs has changed
        if (!_listEqualsUnordered(_lastCharacteristicUuids, currentUuids)) {
          _lastCharacteristicUuids = List.from(currentUuids);
          _restartAllSensors();
        }
      }
    };
    bleBloc.availableCharacteristics.addListener(_characteristicsListener);

    // Listen for characteristic stream version changes (after reconnect)
    _characteristicStreamsVersionListener = () {
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
    final isarService = geolocationBloc.isarService;
    // Initialize sensors with specific UUIDs
    _sensors.add(TemperatureSensor(bleBloc, geolocationBloc, isarService));
    _sensors.add(HumiditySensor(bleBloc, geolocationBloc, isarService));
    _sensors.add(DistanceSensor(bleBloc, geolocationBloc, isarService));
    _sensors.add(
        SurfaceClassificationSensor(bleBloc, geolocationBloc, isarService));
    _sensors.add(AccelerationSensor(bleBloc, geolocationBloc, isarService));
    _sensors
        .add(OvertakingPredictionSensor(bleBloc, geolocationBloc, isarService));
    _sensors.add(SurfaceAnomalySensor(bleBloc, geolocationBloc, isarService));
    _sensors.add(FinedustSensor(bleBloc, geolocationBloc, isarService));
    _sensors.add(GPSSensor(bleBloc, geolocationBloc, isarService));
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

  List<Widget> getSensorWidgets() {
    final availableUuids = bleBloc.availableCharacteristics.value
        .map((e) => e.uuid.toString())
        .toSet();

    final availableSensors = _sensors.where((sensor) {
      if (FeatureFlags.hideSurfaceAnomalySensor &&
          sensor is SurfaceAnomalySensor) {
        return false;
      }
      return availableUuids.contains(sensor.characteristicUuid);
    }).toList();

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
