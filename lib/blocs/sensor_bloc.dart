// File: lib/blocs/sensor_bloc.dart
import 'dart:async';
import 'package:ble_app/blocs/geolocation_bloc.dart';
import 'package:ble_app/sensors/distance_sensor.dart';
import 'package:ble_app/sensors/humidity_sensor.dart';
import 'package:ble_app/sensors/sensor.dart';
import 'package:ble_app/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:ble_app/sensors/temperature_sensor.dart';
import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:isar/isar.dart';

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
      } else {
        _stopListening();
      }
    });
  }

  void _initializeSensors() {
    // Initialize sensors with specific UUIDs
    _sensors.add(TemperatureSensor(bleBloc, geolocationBloc, isarService));
    _sensors.add(HumiditySensor(bleBloc, geolocationBloc, isarService));
    _sensors.add(DistanceSensor(bleBloc, geolocationBloc, isarService));
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
    return _sensors.map((sensor) => sensor.buildWidget()).toList();
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
