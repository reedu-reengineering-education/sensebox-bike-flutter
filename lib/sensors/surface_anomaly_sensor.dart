import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:ble_app/blocs/geolocation_bloc.dart';
import 'package:ble_app/sensors/sensor.dart';
import 'package:ble_app/services/isar_service.dart';
import 'package:flutter/material.dart';

class SurfaceAnomalySensor extends Sensor {
  List<double> _latestAnomalyValue = [0.0];

  static const String sensorCharacteristicUuid =
      'b944af10-f495-4560-968f-2f0d18cab523';

  SurfaceAnomalySensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, bleBloc, geolocationBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.isNotEmpty) {
      _latestAnomalyValue =
          data; // Assuming the first value indicates surface anomaly
    }
  }

  @override
  double aggregateData(List<List<double>> sensorValues) {
    List<double> myValues = sensorValues.map((e) => e[0]).toList();
    // Example aggregation logic: calculating the mean surface anomaly value
    return myValues.reduce((a, b) => a + b) / myValues.length;
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream: valueStream,
      initialData: _latestAnomalyValue,
      builder: (context, snapshot) {
        double displayValue = snapshot.data?[0] ?? _latestAnomalyValue[0];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Surface Anomaly',
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
                    '', // Add any specific unit if applicable
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
