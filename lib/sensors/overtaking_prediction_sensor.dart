import 'dart:math';

import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';

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
}
