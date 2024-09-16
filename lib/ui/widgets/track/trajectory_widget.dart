import 'dart:convert';
import 'dart:math';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
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

  @override
  void initState() {
    super.initState();
    // Set the access token for Mapbox
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  @override
  void didUpdateWidget(TrajectoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensorType != widget.sensorType ||
        oldWidget.geolocationData != widget.geolocationData) {
      addLayer();
    }
  }

  double getMinSensorValue() {
    double minVal = double.infinity;
    for (GeolocationData data in widget.geolocationData) {
      for (SensorData sensor in data.sensorData) {
        if (sensor.title == widget.sensorType) {
          minVal = min(minVal, sensor.value);
        }
      }
    }
    return minVal;
  }

  double getMaxSensorValue() {
    double maxVal = double.negativeInfinity;
    for (GeolocationData data in widget.geolocationData) {
      for (SensorData sensor in data.sensorData) {
        if (sensor.title == widget.sensorType) {
          maxVal = max(maxVal, sensor.value);
        }
      }
    }
    return maxVal;
  }

  Future<void> addLayer() async {
    try {
      // Remove existing layers and sources
      if (await mapInstance.style.getLayer("line_layer") != null) {
        await mapInstance.style.removeStyleLayer("line_layer");
      }
      if (await mapInstance.style.getLayer("point_layer") != null) {
        await mapInstance.style.removeStyleLayer("point_layer");
      }
      if (await mapInstance.style.getSource("lineSource") != null) {
        await mapInstance.style.removeStyleSource("lineSource");
      }
      if (await mapInstance.style.getSource("pointSource") != null) {
        await mapInstance.style.removeStyleSource("pointSource");
      }
    } catch (e) {
      print("Error removing sources and layers: $e");
    }

    // Add new layers
    GeoJsonSource pointSource = GeoJsonSource(
      id: "pointSource",
      data: jsonEncode({
        "type": "FeatureCollection",
        "features": widget.geolocationData
            .map(
              (e) => {
                'type': 'Feature',
                'geometry': {
                  "type": "Point",
                  "coordinates": [
                    e.longitude,
                    e.latitude,
                  ],
                },
                'properties': {
                  for (var sensor in e.sensorData) sensor.title: sensor.value,
                },
              },
            )
            .toList(),
      }),
    );

    GeoJsonSource lineSource = GeoJsonSource(
      id: "lineSource",
      data: jsonEncode({
        "type": "Feature",
        "properties": {},
        "geometry": {
          "type": "LineString",
          "coordinates": widget.geolocationData
              .map((e) => [e.longitude, e.latitude])
              .toList(),
        },
      }),
    );

    await mapInstance.style.addSource(pointSource);
    await mapInstance.style.addSource(lineSource);

    await mapInstance.style.addLayer(LineLayer(
      id: "line_layer",
      sourceId: "lineSource",
    ));

    await mapInstance.style.addLayer(CircleLayer(
      id: "point_layer",
      sourceId: "pointSource",
      circleRadius: 5.0,
      circleColorExpression: [
        "case",
        [
          "to-boolean",
          ["get", widget.sensorType]
        ],
        [
          "interpolate",
          ["linear"],
          ["get", widget.sensorType],
          getMinSensorValue(),
          "blue",
          getMaxSensorValue(),
          "red"
        ],
        "transparent"
      ],
    ));

    // Calculate bounds
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
