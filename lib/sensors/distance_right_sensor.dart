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

class DistanceRightSensor extends Sensor {
  static int get staticUiPriority => 20;

  @override
  int get uiPriority => staticUiPriority;

  static const String sensorCharacteristicUuid =
      'b3491b60-c0f3-4306-a30d-49c91f37a62c';

  DistanceRightSensor(
    BleBloc bleBloc,
    GeolocationBloc geolocationBloc,
    RecordingBloc recordingBloc,
    IsarService isarService,
  ) : super(
          sensorCharacteristicUuid,
          'distance_right',
          const [],
          bleBloc,
          geolocationBloc,
          recordingBloc,
          isarService,
        );

  @override
  Duration get lookbackWindow => const Duration(milliseconds: 2000);

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    final myValues = valueBuffer.map((e) => e[0]).toList();
    final nonZeroValues = myValues.where((value) => value != 0.0).toList();
    if (nonZeroValues.isNotEmpty) {
      return [nonZeroValues.reduce(min)];
    }
    return [0.0];
  }

  @override
  Widget buildWidget() {
    final safeInitial = latestValue.isEmpty ? const [0.0] : latestValue;

    return SensorConditionalRerender(
      valueStream: valueStream,
      initialValue: safeInitial,
      latestValue: safeInitial,
      decimalPlaces: 0,
      builder: (context, value) {
        final currentValue = value[0];
        return SensorCard(
          title: AppLocalizations.of(context)!.sensorDistanceRight,
          icon: getSensorIcon(title),
          color: getSensorColor(title),
          child: SensorValueDisplay(
            value: currentValue.toStringAsFixed(0),
            unit: 'cm',
            isValid: currentValue != 0.0,
          ),
        );
      },
    );
  }
}
