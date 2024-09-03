import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:ble_app/blocs/geolocation_bloc.dart';
import 'package:ble_app/sensors/sensor.dart';
import 'package:ble_app/services/isar_service.dart';
import 'package:flutter/material.dart';

class TemperatureSensor extends Sensor {
  double _latestValue = 0.0;

  static const String sensorCharacteristicUuid =
      '2cdf2174-35be-fdc4-4ca2-6fd173f8b3a8';

  TemperatureSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, bleBloc, geolocationBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.isNotEmpty) {
      _latestValue = data[0]; // Assuming the first value is temperature
    }
  }

  @override
  double aggregateData(List<List<double>> sensorValues) {
    List<double> myValues = sensorValues.map((e) => e[0]).toList();
    // Example aggregation logic: calculating the mean temperature
    return myValues.reduce((a, b) => a + b) / myValues.length;
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<double>(
      stream: valueStream,
      initialData: _latestValue,
      builder: (context, snapshot) {
        double displayValue = snapshot.data ?? _latestValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Temperature',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    displayValue.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 64),
                  ),
                  const Text(
                    '°C',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
