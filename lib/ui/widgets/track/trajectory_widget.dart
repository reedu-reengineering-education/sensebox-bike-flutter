import 'dart:convert';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../secrets.dart'; // File containing the Mapbox token

class TrajectoryWidget extends StatefulWidget {
  final List<GeolocationData> geolocationData;

  const TrajectoryWidget({super.key, required this.geolocationData});

  @override
  State<TrajectoryWidget> createState() =>
      _TrajectoryWidgetState(geolocationData);
}

class _TrajectoryWidgetState extends State<TrajectoryWidget> {
  late final MapboxMap mapInstance;

  List<GeolocationData> geolocationData;

  _TrajectoryWidgetState(this.geolocationData);

  @override
  void initState() {
    super.initState();

    // Set the access token for Mapbox
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void addLayer() async {
    GeoJsonSource data = GeoJsonSource(
      id: "line",
      data: jsonEncode({
        "type": "Feature",
        "properties": {},
        "geometry": {
          "type": "LineString",
          "coordinates":
              geolocationData.map((e) => [e.longitude, e.latitude]).toList()
        }
      }),
    );

    await mapInstance.style.addSource(data);
    await mapInstance.style.addLayer(LineLayer(
        id: "line_layer",
        sourceId: "line",
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineColor: Colors.blue.value,
        lineOpacity: 0.9,
        lineWidth: 8.0));

    // calculate bounds
    GeolocationData southwest = geolocationData.first;
    GeolocationData northeast = geolocationData.first;
    for (GeolocationData data in geolocationData) {
      if (data.latitude < southwest.latitude) {
        southwest = data;
      }
      if (data.latitude > northeast.latitude) {
        northeast = data;
      }
    }

    CameraOptions fitBoundsCamera = await mapInstance.cameraForCoordinateBounds(
        CoordinateBounds(
            southwest: Point(
              coordinates: Position(southwest.longitude, southwest.latitude),
            ),
            northeast: Point(
                coordinates: Position(northeast.longitude, northeast.latitude)),
            infiniteBounds: true),
        MbxEdgeInsets(top: 16, left: 16, right: 16, bottom: 16),
        0,
        0,
        null,
        null);

    await mapInstance.setCamera(fitBoundsCamera);
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      onMapCreated: (mapInstance) async {
        this.mapInstance = mapInstance;
        await mapInstance.scaleBar
            .updateSettings(ScaleBarSettings(enabled: false));
        await mapInstance.location.updateSettings(LocationComponentSettings(
          enabled: true,
          showAccuracyRing: true,
        ));
        addLayer();
      },
    );
  }
}
