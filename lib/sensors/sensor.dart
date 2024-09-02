import 'dart:async';

import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:ble_app/models/geolocation_data.dart';
import 'package:ble_app/models/sensor_data.dart';
import 'package:ble_app/services/isar_service.dart';
import 'package:flutter/material.dart';

abstract class Sensor {
  final String characteristicUuid;
  final BleBloc bleBloc;
  final IsarService isarService; // To store aggregated data
  StreamSubscription<List<double>>? _subscription;
  List<double> _dataBuffer = [];

  Sensor(this.characteristicUuid, this.bleBloc, this.isarService);

  void startListening() {
    _subscription = bleBloc.getCharacteristicStream(characteristicUuid).stream.listen((data) {
      onDataReceived(data);
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }

  void onDataReceived(List<double> data) {
    if (data.isNotEmpty) {
      _dataBuffer.addAll(data);
    }
  }

  void onNewGeolocation(GeolocationData geoData) {
    if (_dataBuffer.isNotEmpty) {
      // Aggregate data
      double aggregatedValue = aggregateData(_dataBuffer);

      SensorData sensorData = SensorData()
        ..characteristicUuid = characteristicUuid
        ..value = aggregatedValue
        ..geolocationData.value = geoData;
        
      isarService.saveSensorData(sensorData);

      // Clear the buffer after storing
      _dataBuffer.clear();
    }
  }

  double aggregateData(List<double> data) {
    // Override this method in subclasses for specific aggregation logic
    // Default to calculating mean
    return data.reduce((a, b) => a + b) / data.length;
  }

  Widget buildWidget() {
    // Override this method in subclasses to build a widget for the sensor
    return Container();
  }

  void dispose() {
    stopListening();
  }
}
