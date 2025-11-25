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

  /// Use a 1500ms (1.5 second) lookback window to capture sensor values that arrive
  /// slightly before or after the geolocation timestamp.
  /// This accounts for GPS timestamp accuracy, sensor transmission delays,
  /// and clock synchronization differences.
  @override
  Duration get lookbackWindow => const Duration(milliseconds: 2000);

  static const String sensorCharacteristicUuid =
      'fc01c688-2c44-4965-ae18-373af9fed18d';

  OvertakingPredictionSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc,
      RecordingBloc recordingBloc,
      IsarService isarService)
      : super(sensorCharacteristicUuid, "overtaking", [], bleBloc,
            geolocationBloc, recordingBloc, isarService);

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
    if (valueBuffer.isEmpty) {
      return [0.0];
    }

    List<double> myValues =
        valueBuffer.map((e) => e.isNotEmpty ? e[0] : 0.0).toList();

    if (myValues.isEmpty) {
      return [0.0];
    }

    final maxValue = myValues.reduce(max);
    
    return [maxValue];
  }

  @override
  Widget buildWidget() {
    return SensorConditionalRerender(
      valueStream: valueStream,
      initialValue: _latestPrediction,
      latestValue: _latestPrediction,
      decimalPlaces: 4,
      builder: (context, value) {
        double displayValue = value[0];

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
              const Text('%'),
            ],
          ),
        );
      },
    );
  }
}
