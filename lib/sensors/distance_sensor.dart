import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:ble_app/blocs/geolocation_bloc.dart';
import 'package:ble_app/sensors/sensor.dart';
import 'package:ble_app/services/isar_service.dart';
import 'package:flutter/material.dart';

class DistanceSensor extends Sensor {
  double _latestValue = 0.0;

  static const String sensorCharacteristicUuid =
      'b3491b60-c0f3-4306-a30d-49c91f37a62b';

  DistanceSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, bleBloc, geolocationBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.isNotEmpty) {
      _latestValue = data[0]; // Assuming the first value is the distance
    }
  }

  @override
  double aggregateData(List<List<double>> sensorValues) {
    List<double> myValues = sensorValues.map((e) => e[0]).toList();
    // Example aggregation logic: calculating the mean distance
    return myValues.reduce((a, b) => a + b) / myValues.length;
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<double>(
      stream: valueStream, // Listen to the stream of distance values
      initialData: _latestValue,
      builder: (context, snapshot) {
        double displayValue = snapshot.data ?? _latestValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Distance',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    displayValue.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 64),
                  ),
                  const Text(
                    'cm',
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
