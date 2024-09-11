import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';

class FinedustSensor extends Sensor {
  double _latestPM1 = 0.0;
  double _latestPM2_5 = 0.0;
  double _latestPM4 = 0.0;
  double _latestPM10 = 0.0;

  @override
  get uiPriority => 80;

  static const String sensorCharacteristicUuid =
      '7e14e070-84ea-489f-b45a-e1317364b979';

  FinedustSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(
            sensorCharacteristicUuid,
            "finedust",
            ['pm1', 'pm2.5', 'pm4', 'pm10'],
            bleBloc,
            geolocationBloc,
            isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.length >= 4) {
      _latestPM1 = data[0];
      _latestPM2_5 = data[1];
      _latestPM4 = data[2];
      _latestPM10 = data[3];
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> sumValues = [0.0, 0.0, 0.0, 0.0];
    int count = valueBuffer.length;

    for (var values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
      sumValues[3] += values[3];
    }

    // Calculate the mean for pm1, pm2.5, pm4, and pm10
    return sumValues.map((value) => value / count).toList();
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream:
          valueStream.map((event) => [event[0], event[1], event[2], event[3]]),
      initialData: [_latestPM1, _latestPM2_5, _latestPM4, _latestPM10],
      builder: (context, snapshot) {
        List<double> displayValues = snapshot.data ??
            [_latestPM1, _latestPM2_5, _latestPM4, _latestPM10];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Finedust Levels',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Text('PM1'),
                      Text(
                        displayValues[0].toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('PM2.5'),
                      Text(
                        displayValues[1].toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('PM4'),
                      Text(
                        displayValues[2].toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('PM10'),
                      Text(
                        displayValues[3].toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
