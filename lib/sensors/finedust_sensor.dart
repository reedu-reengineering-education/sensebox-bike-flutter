import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';

class FinedustSensor extends Sensor {
  static int get staticUiPriority => 80;

  @override
  int get uiPriority => staticUiPriority;

  @override
  Duration get lookbackWindow => const Duration(milliseconds: 1000);

  static const String sensorCharacteristicUuid =
      '7e14e070-84ea-489f-b45a-e1317364b979';

  FinedustSensor(
    BleBloc bleBloc,
    GeolocationBloc geolocationBloc,
    RecordingBloc recordingBloc,
    IsarService isarService,
  ) : super(
          sensorCharacteristicUuid,
          'finedust',
          const ['pm1', 'pm2.5', 'pm4', 'pm10'],
          bleBloc,
          geolocationBloc,
          recordingBloc,
          isarService,
        );

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    final sumValues = [0.0, 0.0, 0.0, 0.0];
    final count = valueBuffer.length;

    for (final values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
      sumValues[3] += values[3];
    }

    return sumValues.map((value) => value / count).toList();
  }
}
