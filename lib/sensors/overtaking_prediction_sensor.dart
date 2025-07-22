import 'dart:math';

import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_conditional_rerender.dart';

class OvertakingPredictionSensor extends Sensor {
  List<double> _latestPrediction = [0.0];

  @override
  get uiPriority => 40;

  static const String sensorCharacteristicUuid =
      'fc01c688-2c44-4965-ae18-373af9fed18d';

  OvertakingPredictionSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc,
      RecordingBloc recordingBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, "overtaking", [],
            bleBloc, geolocationBloc, recordingBloc, isarService);

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
    return SensorConditionalRerender(
      valueStream: valueStream,
      initialValue: _latestPrediction,
      latestValue: _latestPrediction,
      decimalPlaces: 0,
      builder: (context, value) {
        double displayValue = value[0];
        return SensorCard(
          title: AppLocalizations.of(context)!.sensorOvertakingShort,
          icon: getSensorIcon('overtaking_prediction'),
          color: getSensorColor('overtaking_prediction'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                (displayValue * 100).toStringAsFixed(0),
                style: const TextStyle(fontSize: 48),
              ),
              const Text('%'),
            ],
          ),
        );
      },
    );
  }
}
