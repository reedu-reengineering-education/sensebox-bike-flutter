import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';

class AccelerometerSensor extends Sensor {
  double _latestX = 0.0;
  double _latestY = 0.0;
  double _latestZ = 0.0;

  static const String sensorCharacteristicUuid =
      'B944AF10-F495-4560-968F-2F0D18CAB522';

  AccelerometerSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, "accelerometer", ["x", "y", "z"],
            bleBloc, geolocationBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.length >= 3) {
      _latestX = data[0];
      _latestY = data[1];
      _latestZ = data[2];
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> sumValues = [0.0, 0.0, 0.0];
    int count = valueBuffer.length;

    for (var values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
    }

    // Calculate the mean for x, y, and z
    return sumValues.map((value) => value / count).toList();
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream: valueStream.map((event) => [event[0], event[1], event[2]]),
      initialData: [_latestX, _latestY, _latestZ],
      builder: (context, snapshot) {
        List<double> displayValues =
            snapshot.data ?? [_latestX, _latestY, _latestZ];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Accelerometer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('X'),
                      Text(
                        displayValues[0].toStringAsFixed(1),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Y'),
                      Text(
                        displayValues[1].toStringAsFixed(1),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Z'),
                      Text(
                        displayValues[2].toStringAsFixed(1),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ],
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
