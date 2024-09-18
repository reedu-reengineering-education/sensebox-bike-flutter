import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class SurfaceClassificationSensor extends Sensor {
  double _latestAsphalt = 0.0;
  double _latestCompacted = 0.0;
  double _latestPaving = 0.0;
  double _latestSett = 0.0;
  double _latestStanding = 0.0;

  @override
  get uiPriority => 50;

  static const String sensorCharacteristicUuid =
      'b944af10-f495-4560-968f-2f0d18cab521';

  SurfaceClassificationSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(
            sensorCharacteristicUuid,
            "surface_classification",
            ["asphalt", "compacted", "paving", "sett", "standing"],
            bleBloc,
            geolocationBloc,
            isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.length >= 5) {
      _latestAsphalt = data[0];
      _latestCompacted = data[1];
      _latestPaving = data[2];
      _latestSett = data[3];
      _latestStanding = data[4];
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> sumValues = [0.0, 0.0, 0.0, 0.0, 0.0];
    int count = valueBuffer.length;

    for (var values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
      sumValues[3] += values[3];
      sumValues[4] += values[4];
    }

    // Calculate the mean for asphalt, compacted, paving, sett, and standing
    return sumValues.map((value) => value / count).toList();
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream: valueStream
          .map((event) => [event[0], event[1], event[2], event[3], event[4]]),
      initialData: [
        _latestAsphalt,
        _latestCompacted,
        _latestPaving,
        _latestSett,
        _latestStanding
      ],
      builder: (context, snapshot) {
        List<double> displayValues = snapshot.data ??
            [
              _latestAsphalt,
              _latestCompacted,
              _latestPaving,
              _latestSett,
              _latestStanding
            ];

        return SensorCard(
            title: "Surface",
            icon: getSensorIcon(title),
            color: getSensorColor(title),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _buildAttributeRow('Asphalt', displayValues[0]),
                _buildAttributeRow('Compacted', displayValues[1]),
                _buildAttributeRow('Paving', displayValues[2]),
                _buildAttributeRow('Sett', displayValues[3]),
                _buildAttributeRow('Standing', displayValues[4]),
              ],
            ));
      },
    );
  }

  Widget _buildAttributeRow(String attribute, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Text(
            attribute,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8.0),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
