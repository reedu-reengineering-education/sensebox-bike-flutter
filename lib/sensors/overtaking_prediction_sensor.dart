import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:ble_app/blocs/geolocation_bloc.dart';
import 'package:ble_app/sensors/sensor.dart';
import 'package:ble_app/services/isar_service.dart';
import 'package:flutter/material.dart';

class OvertakingPredictionSensor extends Sensor {
  List<double> _latestPrediction = [0.0];

  static const String sensorCharacteristicUuid =
      'fc01c688-2c44-4965-ae18-373af9fed18d';

  OvertakingPredictionSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, bleBloc, geolocationBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.isNotEmpty) {
      _latestPrediction =
          data; // Assuming the first value is the prediction score
    }
  }

  @override
  double aggregateData(List<List<double>> sensorValues) {
    List<double> myValues = sensorValues.map((e) => e[0]).toList();
    // Example aggregation logic: calculating the mean prediction score
    return myValues.reduce((a, b) => a + b) / myValues.length;
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream: valueStream,
      initialData: _latestPrediction,
      builder: (context, snapshot) {
        double displayValue = snapshot.data?[0] ?? _latestPrediction[0];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overtaking Prediction',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    (displayValue * 100).toStringAsFixed(0),
                    style: const TextStyle(fontSize: 64),
                  ),
                  const Text(
                    '%',
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
