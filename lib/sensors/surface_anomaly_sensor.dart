import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';

class SurfaceAnomalySensor extends Sensor {
  static int get staticUiPriority => 60;

  @override
  int get uiPriority => staticUiPriority;

  @override
  Duration get lookbackWindow => const Duration(milliseconds: 1000);

  static const String sensorCharacteristicUuid =
      'b944af10-f495-4560-968f-2f0d18cab523';

  SurfaceAnomalySensor(
    BleBloc bleBloc,
    GeolocationBloc geolocationBloc,
    RecordingBloc recordingBloc,
    IsarService isarService,
  ) : super(
          sensorCharacteristicUuid,
          'surface_anomaly',
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
}
