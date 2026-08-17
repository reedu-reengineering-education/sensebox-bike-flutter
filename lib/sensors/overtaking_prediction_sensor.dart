import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_conditional_rerender.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_value_display.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class OvertakingPredictionSensor extends Sensor {
  static int get staticUiPriority => 30;

  @override
  int get uiPriority => staticUiPriority;

  @override
  Duration get lookbackWindow => const Duration(milliseconds: 2000);

  static const String sensorCharacteristicUuid =
      'fc01c688-2c44-4965-ae18-373af9fed18d';

  OvertakingPredictionSensor(
    BleBloc bleBloc,
    GeolocationBloc geolocationBloc,
    RecordingBloc recordingBloc,
    IsarService isarService,
  ) : super(
          sensorCharacteristicUuid,
          'overtaking',
          const [],
          bleBloc,
          geolocationBloc,
          recordingBloc,
          isarService,
        );

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    if (valueBuffer.isEmpty) {
      return [0.0];
    }

    final myValues = valueBuffer.map((e) => e.isNotEmpty ? e[0] : 0.0).toList();
    if (myValues.isEmpty) {
      return [0.0];
    }

    final maxValue = myValues.reduce(max);
    return [maxValue];
  }

  @override
  Widget buildWidget() {
    final safeInitial = latestValue.isEmpty ? const [0.0] : latestValue;

    return SensorConditionalRerender(
      valueStream: valueStream,
      initialValue: safeInitial,
      latestValue: safeInitial,
      decimalPlaces: 4,
      builder: (context, value) {
        return SensorCard(
          title: AppLocalizations.of(context)!.sensorOvertaking,
          icon: getSensorIcon(title),
          color: getSensorColor(title),
          child: SensorValueDisplay(
            value: (value[0] * 100).toStringAsFixed(0),
            unit: '%',
          ),
        );
      },
    );
  }
}
