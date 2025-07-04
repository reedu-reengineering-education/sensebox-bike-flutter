import 'dart:math';

import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class OvertakingPredictionSensor extends Sensor {
  List<double> _latestPrediction = [0.0];

  @override
  get uiPriority => 40;

  static const String sensorCharacteristicUuid =
      'fc01c688-2c44-4965-ae18-373af9fed18d';

  OvertakingPredictionSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, "overtaking", [], bleBloc,
            geolocationBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.isNotEmpty) {
      _latestPrediction =
          data; // Assuming the first value is the prediction score
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> myValues = valueBuffer.map((e) => e[0]).toList();
    return [myValues.reduce(max)];
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream: valueStream,
      initialData: _latestPrediction,
      builder: (context, snapshot) {
        double displayValue = snapshot.data?[0] ?? _latestPrediction[0];

        return SensorCard(
            title: AppLocalizations.of(context)!.sensorOvertakingShort,
            icon: getSensorIcon(title),
            color: getSensorColor(title),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  (displayValue * 100).toStringAsFixed(0),
                  style: const TextStyle(fontSize: 48),
                ),
                const Text(
                  '%',
                ),
              ],
            ));
      },
    );
  }
}
