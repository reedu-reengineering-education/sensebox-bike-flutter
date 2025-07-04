import 'dart:math';

import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class DistanceSensor extends Sensor {
  List<double> _latestValue = [0.0];

  @override
  get uiPriority => 30;

  static const String sensorCharacteristicUuid =
      'b3491b60-c0f3-4306-a30d-49c91f37a62b';

  DistanceSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, "distance", [], bleBloc,
            geolocationBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.isNotEmpty) {
      _latestValue = data; // Assuming the first value is the distance
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> myValues = valueBuffer.map((e) => e[0]).toList();
    return [myValues.reduce(min)];
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream: valueStream, // Listen to the stream of distance values
      initialData: _latestValue,
      builder: (context, snapshot) {
        return SensorCard(
            title: AppLocalizations.of(context)!.sensorDistanceShort,
            icon: getSensorIcon(title),
            color: getSensorColor(title),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _latestValue[0].toStringAsFixed(0),
                  style: const TextStyle(fontSize: 48),
                ),
                const Text(
                  'cm',
                ),
              ],
            ));
      },
    );
  }
}
