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

class TemperatureSensor extends Sensor {
  static int get staticUiPriority => 40;

  @override
  int get uiPriority => staticUiPriority;

  @override
  Duration get lookbackWindow => const Duration(milliseconds: 1000);

  static const String sensorCharacteristicUuid =
      '2cdf2174-35be-fdc4-4ca2-6fd173f8b3a8';

  TemperatureSensor(
    BleBloc bleBloc,
    GeolocationBloc geolocationBloc,
    RecordingBloc recordingBloc,
    IsarService isarService,
  ) : super(
          sensorCharacteristicUuid,
          'temperature',
          const [],
          bleBloc,
          geolocationBloc,
          recordingBloc,
          isarService,
        );

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    final myValues = valueBuffer.map((e) => e[0]).toList();
    return [myValues.reduce((a, b) => a + b) / myValues.length];
  }

  @override
  Widget buildWidget() {
    final safeInitial = latestValue.isEmpty ? const [0.0] : latestValue;

    return SensorConditionalRerender(
      valueStream: valueStream,
      initialValue: safeInitial,
      latestValue: safeInitial,
      decimalPlaces: 1,
      builder: (context, value) {
        return SensorCard(
          title: AppLocalizations.of(context)!.sensorTemperature,
          icon: getSensorIcon(title),
          color: getSensorColor(title),
          child: SensorValueDisplay(
            value: value[0].toStringAsFixed(1),
            unit: '°C',
          ),
        );
      },
    );
  }
}
