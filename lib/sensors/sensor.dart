import 'dart:async';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';

abstract class Sensor {
  final String characteristicUuid;
  final String title;
  final List<String> attributes;

  final BleBloc bleBloc;
  final GeolocationBloc geolocationBloc;
  final IsarService isarService;
  StreamSubscription<List<double>>? _subscription;

  final StreamController<List<double>> _valueController =
      StreamController<List<double>>.broadcast();
  Stream<List<double>> get valueStream => _valueController.stream;

  final List<List<double>> _valueBuffer = [];

  late int uiPriority;

  late Icon uiIcon;
  late Color uiColor;

  Sensor(
    this.characteristicUuid,
    this.title,
    this.attributes,
    this.bleBloc,
    this.geolocationBloc,
    this.isarService,
  );

  void startListening() {
    try {
      // Listen to the sensor data stream
      _subscription = bleBloc
          .getCharacteristicStream(characteristicUuid)
          .stream
          .listen((data) {
        onDataReceived(data);
      });

      // Listen to geolocation updates
      geolocationBloc.geolocationStream.listen((geolocationData) {
        if (_valueBuffer.isNotEmpty) {
          _aggregateAndStoreData(
              geolocationData); // Aggregate and store sensor data
          _valueBuffer.clear(); // Clear the list after aggregation
        }
      });
    } catch (e) {
      print('Error starting sensor: $e');
    }
  }

  void stopListening() {
    _subscription?.cancel();
  }

  // Method to handle incoming sensor data
  void onDataReceived(List<double> data) {
    if (data.isNotEmpty) {
      _valueBuffer.add(data); // Buffer the sensor data
      _valueController.add(data); // Emit the latest sensor value to the stream
    }
  }

  // Aggregate sensor data and store it with the latest geolocation
  void _aggregateAndStoreData(GeolocationData geolocationData) {
    List<double> aggregatedValues = aggregateData(_valueBuffer);

    if (attributes.isEmpty) {
      _saveSensorData(aggregatedValues[0], null, geolocationData);
    } else {
      if (attributes.length != aggregatedValues.length) {
        throw Exception(
            'Number of attributes does not match the number of aggregated values');
      }

      for (int i = 0; i < attributes.length; i++) {
        _saveSensorData(aggregatedValues[i], attributes[i], geolocationData);
      }
    }
  }

  // Helper method to save sensor data
  void _saveSensorData(
      double value, String? attribute, GeolocationData geolocationData) {
    isarService.geolocationService.saveGeolocationData(geolocationData);

    final sensorData = SensorData()
      ..characteristicUuid = characteristicUuid
      ..title = title
      ..value = value
      ..attribute = attribute
      ..geolocationData.value = geolocationData;

    isarService.sensorService.saveSensorData(sensorData);
  }

  // Abstract method to build a widget for the sensor (UI representation)
  Widget buildWidget();

  // Abstract method to aggregate sensor data
  List<double> aggregateData(List<List<double>> valueBuffer);

  void dispose() {
    stopListening();
    _valueController
        .close(); // Close the stream controller to prevent memory leaks
  }
}
