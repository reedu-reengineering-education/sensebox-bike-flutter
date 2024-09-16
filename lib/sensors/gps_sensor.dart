import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';

class GPSSensor extends Sensor {
  double _latestLat = 0.0;
  double _latestLng = 0.0;
  double _latestSpd = 0.0;

  late final MapboxMap mapInstance;

  @override
  get uiPriority => 25;

  static const String sensorCharacteristicUuid =
      '8edf8ebb-1246-4329-928d-ee0c91db2389';

  GPSSensor(
      BleBloc bleBloc, GeolocationBloc geolocationBloc, IsarService isarService)
      : super(
            sensorCharacteristicUuid,
            "gps",
            ["latitude", "longitude", "speed"],
            bleBloc,
            geolocationBloc,
            isarService) {
    // Set the access token for Mapbox
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  @override
  void onDataReceived(List<double> data) {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.length >= 3) {
      _latestLat = data[0];
      _latestLng = data[1];
      _latestSpd = data[2];

      mapInstance.flyTo(
        CameraOptions(
          zoom: 16.0,
          pitch: 45,
          center: Point(coordinates: Position(_latestLng, _latestLat)),
        ),
        MapAnimationOptions(
          duration: 1000,
        ),
      );
    }
  }

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    List<double> sumValues = [0.0, 0.0, 0.0];
    int count = valueBuffer.length;

    for (var values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
    }

    // Calculate the mean for x, y, and z
    return sumValues.map((value) => value / count).toList();
  }

  @override
  Widget buildWidget() {
    return Card(
      child: MapWidget(onMapCreated: (mapInstance) {
        this.mapInstance = mapInstance;
        mapInstance.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
      }),
      clipBehavior: Clip.hardEdge,
    );
  }
}
