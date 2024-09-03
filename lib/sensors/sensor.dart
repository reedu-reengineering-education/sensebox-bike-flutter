import 'dart:async';
import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:ble_app/blocs/geolocation_bloc.dart';
import 'package:ble_app/models/sensor_data.dart';
import 'package:ble_app/models/geolocation_data.dart';
import 'package:ble_app/services/isar_service.dart';
import 'package:flutter/material.dart';

abstract class Sensor {
  final String characteristicUuid;
  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final IsarService isarService;
  StreamSubscription<List<double>>? _subscription;

  final StreamController<List<double>> _valueController =
      StreamController<List<double>>.broadcast();
  Stream<List<double>> get valueStream => _valueController.stream;

  final List<List<double>> _sensorValues = [];

  Sensor(
    this.characteristicUuid,
    this.bleBloc,
    this.geolocationBloc,
    this.isarService,
  );

  void startListening() {
    // Listen to the sensor data stream
    _subscription = bleBloc
        .getCharacteristicStream(characteristicUuid)
        .stream
        .listen((data) {
      onDataReceived(data);
    });

    // Listen to geolocation updates
    geolocationBloc.geolocationStream.listen((geolocationData) {
      if (_sensorValues.isNotEmpty) {
        _aggregateAndStoreData(
            geolocationData); // Aggregate and store sensor data
        _sensorValues.clear(); // Clear the list after aggregation
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }

  // Method to handle incoming sensor data
  void onDataReceived(List<double> data) {
    if (data.isNotEmpty) {
      _sensorValues.add(data); // Buffer the sensor data
      _valueController.add(data); // Emit the latest sensor value to the stream
    }
  }

  // Aggregate sensor data and store it with the latest geolocation
  void _aggregateAndStoreData(GeolocationData geolocationData) {
    double aggregatedValue = aggregateData(_sensorValues);
    // Additional aggregations can be added here

    // Create a SensorData object to store in the database
    final sensorData = SensorData()
      ..characteristicUuid = characteristicUuid
      ..value = aggregatedValue
      ..geolocationData.value = geolocationData;

    isarService
        .saveSensorData(sensorData); // Save aggregated data to the database
  }

  // Abstract method to build a widget for the sensor (UI representation)
  Widget buildWidget();

  // Abstract method to aggregate sensor data
  double aggregateData(List<List<double>> sensorValues);

  void dispose() {
    stopListening();
    _valueController
        .close(); // Close the stream controller to prevent memory leaks
  }
}
