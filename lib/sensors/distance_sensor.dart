import 'dart:math';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_value_display.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_conditional_rerender.dart';

class DistanceSensor extends Sensor {
  List<double> _latestValue = [0.0];

  @override
  get uiPriority => 30;

  static const String sensorCharacteristicUuid =
      'b3491b60-c0f3-4306-a30d-49c91f37a62b';

  DistanceSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc,
      RecordingBloc recordingBloc,
      IsarService isarService)
      : super(sensorCharacteristicUuid, "distance", [], bleBloc,
            geolocationBloc, recordingBloc, isarService);

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
    
    // Filter out zero values
    List<double> nonZeroValues = myValues.where((value) => value != 0.0).toList();

    if (nonZeroValues.isNotEmpty) {
      return [nonZeroValues.reduce(min)];
    }
    
    return [0.0];
  }

  @override
  Widget buildWidget() {
    return SensorConditionalRerender(
      valueStream: valueStream,
      initialValue: _latestValue,
      latestValue: _latestValue,
      decimalPlaces: 0,
      builder: (context, value) {
        return SensorCard(
          title: AppLocalizations.of(context)!.sensorDistanceShort,
          icon: getSensorIcon(title),
          color: getSensorColor(title),
          child: SensorValueDisplay(
            value: value[0].toStringAsFixed(0),
            unit: 'cm',
            isValid: value[0] != 0.0,
          ),
        );
      },
    );
  }
}
