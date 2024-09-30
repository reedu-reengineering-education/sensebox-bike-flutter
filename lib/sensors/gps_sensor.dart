import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class GPSSensor extends Sensor {
  double _latestLat = 0.0;
  double _latestLng = 0.0;
  double _latestSpd = 0.0;

  late final MapboxMap mapInstance;

  @override
  get uiPriority => 25;

  static const String sensorCharacteristicUuid =
      '8edf8ebb-1246-4329-928d-ee0c91db2389';

  CircleAnnotationManager? circleAnnotationManager;

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
  void onDataReceived(List<double> data) async {
    super.onDataReceived(data); // Call the parent class to handle buffering
    if (data.length >= 3) {
      _latestLat = data[0];
      _latestLng = data[1];
      _latestSpd = data[2];

      if (_latestLat == 0.0 && _latestLng == 0.0) {
        return;
      }

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

      CircleAnnotationOptions option = CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_latestLng, _latestLat)),
          circleColor: Colors.blue.value,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 1);

      circleAnnotationManager!.deleteAll();

      // Create new annotations
      await circleAnnotationManager!.createMulti([option]);
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
    if (_latestLat == 0.0 && _latestLng == 0.0) {
      return SensorCard(
        icon: getSensorIcon(title),
        color: getSensorColor(title),
        title: 'GPS',
        child: const Center(
          child: Text("No GPS Fix"),
        ),
      );
    }
    return Card(
      elevation: 1,
      clipBehavior: Clip.hardEdge,
      child: ReusableMapWidget(onMapCreated: (mapInstance) async {
        this.mapInstance = mapInstance;
        mapInstance.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

        circleAnnotationManager ??=
            await mapInstance.annotations.createCircleAnnotationManager();
      }),
    );
  }
}
