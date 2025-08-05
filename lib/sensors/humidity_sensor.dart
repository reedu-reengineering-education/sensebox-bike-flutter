import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_conditional_rerender.dart';

class HumiditySensor extends Sensor {
  List<double> _latestValue = [0.0];

  @override
  get uiPriority => 20;

  static const String sensorCharacteristicUuid =
      '772df7ec-8cdc-4ea9-86af-410abe0ba257';

  HumiditySensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc,
      RecordingBloc recordingBloc,
      SettingsBloc settingsBloc,
      IsarService isarService)
      : super(sensorCharacteristicUuid, "humidity", [], bleBloc,
            geolocationBloc, recordingBloc, settingsBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.isNotEmpty) {
      _latestValue = data; // Assuming the first value is the value
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> myValues = valueBuffer.map((e) => e[0]).toList();
    // Example aggregation logic: calculating the mean temperature
    return [myValues.reduce((a, b) => a + b) / myValues.length];
  }

  @override
  Widget buildWidget() {
    return SensorConditionalRerender(
      valueStream: valueStream,
      initialValue: _latestValue,
      latestValue: _latestValue,
      decimalPlaces: 1,
      builder: (context, value) {
        return SensorCard(
            title: AppLocalizations.of(context)!.sensorHumidity,
            icon: getSensorIcon(title),
            color: getSensorColor(title),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value[0].toStringAsFixed(1),
                  style: const TextStyle(fontSize: 48),
                ),
                const Text('%'),
              ],
            ));
      },
    );
  }
}
