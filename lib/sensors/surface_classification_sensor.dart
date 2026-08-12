import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';

class SurfaceClassificationSensor extends Sensor {
  static int get staticUiPriority => 60;

  @override
  int get uiPriority => staticUiPriority;

  @override
  Duration get lookbackWindow => const Duration(milliseconds: 1000);

  static const String sensorCharacteristicUuid =
      'b944af10-f495-4560-968f-2f0d18cab521';

  SurfaceClassificationSensor(
    BleBloc bleBloc,
    GeolocationBloc geolocationBloc,
    RecordingBloc recordingBloc,
    IsarService isarService,
  ) : super(
          sensorCharacteristicUuid,
          'surface_classification',
          const ['asphalt', 'compacted', 'paving', 'sett', 'standing'],
          bleBloc,
          geolocationBloc,
          recordingBloc,
          isarService,
        );

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    final sumValues = [0.0, 0.0, 0.0, 0.0, 0.0];
    final count = valueBuffer.length;

    for (final values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
      sumValues[3] += values[3];
      sumValues[4] += values[4];
    }

    return sumValues.map((value) => value / count).toList();
  }
}
