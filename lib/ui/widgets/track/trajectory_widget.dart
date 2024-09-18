import 'dart:convert';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import '../../../secrets.dart'; // File containing the Mapbox token

class TrajectoryWidget extends StatefulWidget {
  final List<GeolocationData> geolocationData;
  final String sensorType;

  const TrajectoryWidget({
    super.key,
    required this.geolocationData,
    required this.sensorType,
  });

  @override
  State<TrajectoryWidget> createState() => _TrajectoryWidgetState();
}

class _TrajectoryWidgetState extends State<TrajectoryWidget> {
  late MapboxMap mapInstance;
  double? minSensorValue;
  double? maxSensorValue;

  @override
  void initState() {
    super.initState();
    // Set the access token for Mapbox
    MapboxOptions.setAccessToken(mapboxAccessToken);

    minSensorValue =
        getMinSensorValue(widget.geolocationData, widget.sensorType);
    maxSensorValue =
        getMaxSensorValue(widget.geolocationData, widget.sensorType);
  }

  @override
  void didUpdateWidget(TrajectoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensorType != widget.sensorType ||
        oldWidget.geolocationData != widget.geolocationData) {
      addLayer();
    }
  }

  Future<void> addLayer() async {
    try {
      // Remove existing layers and sources
      if (await mapInstance.style.styleLayerExists("line_layer")) {
        await mapInstance.style.removeStyleLayer("line_layer");
      }
      if (await mapInstance.style.styleSourceExists("lineSource")) {
        await mapInstance.style.removeStyleSource("lineSource");
      }
    } catch (e) {
      print("Error removing sources and layers: $e");
    }

    // Add new GeoJson source
    GeoJsonSource lineSource = GeoJsonSource(
      id: "lineSource",
      data: jsonEncode({
        "type": "FeatureCollection",
        "features": List.generate(widget.geolocationData.length - 1, (index) {
          GeolocationData current = widget.geolocationData[index];
          GeolocationData next = widget.geolocationData[index + 1];

          return {
            "type": "Feature",
            'properties': {
              for (var sensor in current.sensorData)
                '${sensor.title}${sensor.attribute == null ? '' : '_${sensor.attribute}'}':
                    sensor.value,
            },
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [current.longitude, current.latitude],
                [next.longitude, next.latitude]
              ],
            },
          };
        })
      }),
    );

    await mapInstance.style.addSource(lineSource);

    minSensorValue =
        getMinSensorValue(widget.geolocationData, widget.sensorType);
    maxSensorValue =
        getMaxSensorValue(widget.geolocationData, widget.sensorType);

    // Add a LineLayer with color interpolation based on sensor values
    await mapInstance.style.addLayer(LineLayer(
      id: "line_layer",
      sourceId: "lineSource",
      // Use the sensor type as the property for the color expression
      // This will be used to interpolate the color of the line based on the sensor values
      // If the sensor value is not a number, the line will be transparent
      lineColorExpression: [
        "case",
        [
          "==",
          [
            "typeof",
            ["get", widget.sensorType]
          ],
          "number"
        ],
        [
          "interpolate",
          ["linear"],
          ["get", widget.sensorType],
          minSensorValue!,
          'green',
          minSensorValue! +
              (maxSensorValue! -
                      getMinSensorValue(
                          widget.geolocationData, widget.sensorType)) *
                  0.5,
          'orange',
          maxSensorValue!,
          'red'
        ],
        "transparent"
      ],
      lineWidth: 4.0, // Adjust the width as needed
      lineCap: LineCap.ROUND,
    ));

    // Adjust the camera to fit the bounds of the trajectory
    GeolocationData south = widget.geolocationData.first;
    GeolocationData west = widget.geolocationData.first;
    GeolocationData north = widget.geolocationData.first;
    GeolocationData east = widget.geolocationData.first;

    for (GeolocationData data in widget.geolocationData) {
      if (data.latitude < south.latitude) {
        south = data;
      }
      if (data.latitude > north.latitude) {
        north = data;
      }
      if (data.longitude < west.longitude) {
        west = data;
      }
      if (data.longitude > east.longitude) {
        east = data;
      }
    }

    Point southwest = Point(
      coordinates: Position(west.longitude, south.latitude),
    );

    Point northeast = Point(
      coordinates: Position(east.longitude, north.latitude),
    );

    CameraOptions fitBoundsCamera = await mapInstance.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: southwest,
        northeast: northeast,
        infiniteBounds: true,
      ),
      MbxEdgeInsets(top: 16, left: 32, right: 32, bottom: 16),
      0,
      0,
      null,
      null,
    );

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
        addLayer(); // Call addLayer when the map is created
      },
    );
  }
}
