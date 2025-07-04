import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class SurfaceAnomalySensor extends Sensor {
  List<double> _latestAnomalyValue = [0.0];

  @override
  get uiPriority => 60;

  static const String sensorCharacteristicUuid =
      'b944af10-f495-4560-968f-2f0d18cab523';

  SurfaceAnomalySensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(sensorCharacteristicUuid, "surface_anomaly", [], bleBloc,
            geolocationBloc, isarService);

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.isNotEmpty) {
      _latestAnomalyValue =
          data; // Assuming the first value indicates surface anomaly
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> myValues = valueBuffer.map((e) => e[0]).toList();
    // Example aggregation logic: calculating the mean surface anomaly value
    return [myValues.reduce((a, b) => a + b) / myValues.length];
  }

  @override
  Widget buildWidget() {
    return StreamBuilder<List<double>>(
      stream: valueStream,
      initialData: _latestAnomalyValue,
      builder: (context, snapshot) {
        double displayValue = snapshot.data?[0] ?? _latestAnomalyValue[0];
        return SensorCard(
            title: AppLocalizations.of(context)!.sensorSurfaceAnomaly,
            icon: getSensorIcon(title),
            color: getSensorColor(title),
            child: Text(
              displayValue.toStringAsFixed(1),
              style: const TextStyle(fontSize: 48),
            ));
      },
    );
  }
}
