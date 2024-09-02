// File: lib/blocs/sensor_bloc.dart
import 'dart:async';
import 'package:ble_app/sensors/sensor.dart';
import 'package:ble_app/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:ble_app/sensors/temperature_sensor.dart';
import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:isar/isar.dart';

class SensorBloc with ChangeNotifier {
  final BleBloc bleBloc;
  final List<Sensor> _sensors = [];

  final IsarService isarService = IsarService(); // To store aggregated data
  // Add other sensor types as needed

  SensorBloc(this.bleBloc) {
    _initializeSensors();

    // when bleBloc is ready, start listening to sensors
    bleBloc.addListener(() {
      if (bleBloc.selectedDevice != null) {
        _startListening();
      }
    });
  }

  void _initializeSensors() {
    // Initialize sensors with specific UUIDs
    _sensors.add(TemperatureSensor(bleBloc, isarService));
  }

  void _startListening() {
    for (var sensor in _sensors) {
      sensor.startListening();
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
    super.dispose();
  }
}
