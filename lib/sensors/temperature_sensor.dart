import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:ble_app/sensors/sensor.dart';
import 'package:ble_app/services/isar_service.dart';
import 'package:flutter/material.dart';

class TemperatureSensor extends Sensor {
  double _latestTemperature = 0.0;

  static const String sensorCharacteristicUuid = '2CDF2174-35BE-FDC4-4CA2-6FD173F8B3A8';


  TemperatureSensor(BleBloc bleBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, bleBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.isNotEmpty) {
      _latestTemperature = data[0]; // Assuming the first value is temperature
    }
  }

  @override
  double aggregateData(List<double> data) {
    // Example aggregation logic: calculating the mean temperature
    return data.reduce((a, b) => a + b) / data.length;
  }

  Widget buildWidget() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              'Temperature Sensor',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_latestTemperature.toStringAsFixed(2)} °C',
              style: TextStyle(fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}
