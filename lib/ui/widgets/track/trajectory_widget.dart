import 'dart:convert';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';
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

  Future<void> _removeLayersAndSources(MapboxMap map) async {
    final layers = ['line_layer_bg', 'line_layer', 'pointLayer'];
    final sources = ['lineSource', 'pointSource'];

    for (final layer in layers) {
      try {
        if (await map.style.styleLayerExists(layer)) {
          await map.style.removeStyleLayer(layer);
        }
      } catch (e) {
        debugPrint("Error removing layer $layer: $e");
      }
    }
    for (final source in sources) {
      try {
        if (await map.style.styleSourceExists(source)) {
          await map.style.removeStyleSource(source);
        }
      } catch (e) {
        debugPrint("Error removing source $source: $e");
      }
    }
  }

  Future<void> addLayer() async {
    minSensorValue =
        getMinSensorValue(widget.geolocationData, widget.sensorType);
    maxSensorValue =
        getMaxSensorValue(widget.geolocationData, widget.sensorType);
    // If sensor values are not available, return early
    if (minSensorValue == double.infinity ||
        maxSensorValue == double.negativeInfinity) {
      debugPrint(
        'TrajectoryWidget: No valid sensor values found for sensorType "${widget.sensorType}". Skipping layer addition.',
      );
      return;
    }

    try {
      await _removeLayersAndSources(mapInstance);
    } catch (_) {}

    // Add trajectory line
    await mapInstance.style.addLayer(LineLayer(
      id: "line_layer_bg",
      sourceId: "lineSource",
      lineColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.blueGrey[50]?.value
          : Colors.blueGrey[900]?.value,
      lineWidth: 4.0,
      lineCap: LineCap.ROUND,
      lineEmissiveStrength: 1,
    ));

    if (minSensorValue != maxSensorValue) {
      await _addLineLayer();
    } else {
      await _addPointLayer();
    }

    await _fitCameraToTrajectory();
  }

  List<dynamic> _sensorColorExpression() {
    return [
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
        minSensorValue! + (maxSensorValue! - minSensorValue!) * 0.5,
        'orange',
        maxSensorValue!,
        'red'
      ],
      "transparent"
    ];
  }

  Future<void> _addLineLayer() async {
    final features = _buildFeatures();
    final lineSource = GeoJsonSource(
      id: "lineSource",
      data: jsonEncode({"type": "FeatureCollection", "features": features}),
    );
    try {
      await mapInstance.style.addSource(lineSource);
      // Add a LineLayer with color interpolation based on sensor values
      await mapInstance.style.addLayer(LineLayer(
          id: "line_layer",
          sourceId: "lineSource",
          lineColorExpression: _sensorColorExpression().cast<Object>(),
          lineWidth: 12.0,
          lineCap: LineCap.ROUND,
          lineEmissiveStrength: 1));
    } catch (e) {
      debugPrint("Error adding line layer: $e");
    }
  }

  Future<void> _addPointLayer() async {
    final pointData = widget.geolocationData.first;
    final sensorValue = minSensorValue!;
    final circleColor = _getColorForSensorValue(sensorValue);

    final pointSource = GeoJsonSource(
      id: "pointSource",
      data: jsonEncode({
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [pointData.longitude, pointData.latitude],
            },
            "properties": {"sensorValue": sensorValue},
          },
        ],
      }),
    );

    try {
      await mapInstance.style.addSource(pointSource);
      await mapInstance.style.addLayer(CircleLayer(
        id: "pointLayer",
        sourceId: "pointSource",
        circleColorExpression: _sensorColorExpression().cast<Object>(),
        circleRadius: 12.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: circleColor,
      ));
    } catch (e) {
      debugPrint("Error adding point layer: $e");
    }
  }

  List<Map<String, dynamic>> _buildFeatures() {
    return List.generate(widget.geolocationData.length - 1, (index) {
      final current = widget.geolocationData[index];
      final next = widget.geolocationData[index + 1];
      return {
        "type": "Feature",
        "properties": {
          for (var sensor in current.sensorData)
            if (!sensor.value.isNaN)
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
    });
  }

  int _getColorForSensorValue(double value) {
    if (value <= minSensorValue!) {
      return Colors.green.value;
    } else if (value <=
        minSensorValue! + (maxSensorValue! - minSensorValue!) * 0.5) {
      return Colors.orange.value;
    } else {
      return Colors.red.value;
    }
  }

Future<void> _fitCameraToTrajectory() async {
    GeolocationData south = widget.geolocationData.first;
    GeolocationData west = widget.geolocationData.first;
    GeolocationData north = widget.geolocationData.first;
    GeolocationData east = widget.geolocationData.first;

    for (GeolocationData data in widget.geolocationData) {
      if (data.latitude < south.latitude) south = data;
      if (data.latitude > north.latitude) north = data;
      if (data.longitude < west.longitude) west = data;
      if (data.longitude > east.longitude) east = data;
    }

    final southwest =
        Point(coordinates: Position(west.longitude, south.latitude));
    final northeast =
        Point(coordinates: Position(east.longitude, north.latitude));

    final fitBoundsCamera = await mapInstance.cameraForCoordinateBounds(
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
    try {
      await mapInstance.flyTo(
        fitBoundsCamera, MapAnimationOptions(duration: 1000));
    } catch (e) {
      debugPrint("Error fitting camera to bounds: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReusableMapWidget(
      logoMargins: const EdgeInsets.all(4),
      attributionMargins: const EdgeInsets.all(4),
      onMapCreated: (mapInstance) async {
        this.mapInstance = mapInstance;
        await mapInstance.scaleBar
            .updateSettings(ScaleBarSettings(enabled: false));
        await mapInstance.location.updateSettings(LocationComponentSettings(
          enabled: true,
          showAccuracyRing: true,
        ));
        // wait for some time to ensure the map is fully loaded
        await Future.delayed(const Duration(milliseconds: 500));
        addLayer(); // Call addLayer when the map is created
      },
    );
  }
}
