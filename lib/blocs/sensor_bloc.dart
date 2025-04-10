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
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';

class SensorBloc with ChangeNotifier {
  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final List<Sensor> _sensors = [];
  final IsarService isarService = IsarService(); // To store aggregated data

  SensorBloc(this.bleBloc, this.geolocationBloc) {
    _initializeSensors();

    // Listen to changes in the BLE device connection state
    bleBloc.selectedDeviceNotifier.addListener(() {
      if (bleBloc.selectedDevice != null &&
          bleBloc.selectedDevice!.isConnected) {
        _startListening();
        geolocationBloc.startListening();
      } else {
        _stopListening();
        geolocationBloc.stopListening();
      }
    });
  }

  void _initializeSensors() {
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

  List<Widget> getSensorWidgets() {
    // get available characteristics from bleBloc
    final availableCharacteristics = bleBloc.availableCharacteristics.value;

    final List<Sensor> availableSensors = [];

    // get all sensors with this characteristic
    for (var sensor in _sensors) {
      // Check if the sensor should be excluded based on the feature flag
      if (FeatureFlags.hideSurfaceAnomalySensor &&
          sensor is SurfaceAnomalySensor) {
        continue;
      }
      if (availableCharacteristics
          .map((e) => e.uuid.toString())
          .contains(sensor.characteristicUuid)) {
        availableSensors.add(sensor);
      }
    }

    availableSensors.sort((a, b) => a.uiPriority.compareTo(b.uiPriority));
    return availableSensors.map((sensor) => sensor.buildWidget()).toList();
  }

  @override
  void dispose() {
    for (var sensor in _sensors) {
      sensor.dispose();
    }
    bleBloc.selectedDeviceNotifier.removeListener(() {
      if (bleBloc.selectedDevice != null &&
          bleBloc.selectedDevice!.isConnected) {
        _startListening();
      } else {
        _stopListening();
      }
    });
    super.dispose();
  }
}
