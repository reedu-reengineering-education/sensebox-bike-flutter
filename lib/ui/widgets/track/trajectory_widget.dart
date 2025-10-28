import 'dart:convert';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import '../../../secrets.dart'; 

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

  static const String lineSourceId = "lineSource";
  static const String lineLayerBGId = "line_layer_bg";
  static const String sensorLayerId = "sensorLayer";
  static const String sensorSourceId = "sensorSource";

  @override
  void initState() {
    super.initState();
    // Set the access token for Mapbox
    MapboxOptions.setAccessToken(mapboxAccessToken);

    _updateSensorRange();
  }

  @override
  void didUpdateWidget(TrajectoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensorType != widget.sensorType ||
        oldWidget.geolocationData != widget.geolocationData) {
      _updateSensorRange();
      addLayer();
    }
  }

  void _updateSensorRange() {
    minSensorValue =
        getMinSensorValue(widget.geolocationData, widget.sensorType);
    maxSensorValue =
        getMaxSensorValue(widget.geolocationData, widget.sensorType);
  }

  Future<void> _removeLayersAndSources(MapboxMap map) async {
    final layers = [lineLayerBGId, sensorLayerId];
    final sources = [lineSourceId, sensorSourceId];

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

  Future<void> _addBackgroundLineLayer() async {
    final features = _buildFeatures();
    final lineSource = GeoJsonSource(
      id: lineSourceId,
      data: jsonEncode({"type": "FeatureCollection", "features": features}),
    );

    try {
      await mapInstance.style.addSource(lineSource);
      await mapInstance.style.addLayer(LineLayer(
        id: lineLayerBGId,
        sourceId: lineSourceId,
        lineColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.blueGrey[50]?.value
            : Colors.blueGrey[900]?.value,
        lineWidth: 4.0,
        lineCap: LineCap.ROUND,
        lineEmissiveStrength: 1,
      ));
    } catch (e) {
      debugPrint("Error adding background line layer: $e");
    }
  }

  List<Object> get _sensorColorStops {
    // Special handling for distance sensor - if value is 0.0, color should be grey
    if (widget.sensorType == 'distance') {
      if (minSensorValue == 0.0) {
        // Range includes 0 - 0 is grey, >0 follows red->orange->green
        return [
          0.0,
          'grey',
          maxSensorValue! * 0.33, // 1/3 of max = red
          'red',
          maxSensorValue! * 0.66, // 2/3 of max = orange
          'orange',
          maxSensorValue!,
          'green'
        ];
      } else {
        // Range doesn't include 0 - normal red->orange->green gradient
        return [
          minSensorValue!,
          'red',
          minSensorValue! + (maxSensorValue! - minSensorValue!) * 0.5,
          'orange',
          maxSensorValue!,
          'green'
        ];
      }
    }

    // Default behavior for other sensors
    return [
      minSensorValue!,
      'green',
      minSensorValue! + (maxSensorValue! - minSensorValue!) * 0.5,
      'orange',
      maxSensorValue!,
      'red'
    ];
  }

  List<Object> _sensorColorExpression() {
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
        ..._sensorColorStops,
      ],
      "transparent"
    ];
  }


  Future<void> _addLineLayer() async {
    try {
      final features = _buildFeatures();
      final source = GeoJsonSource(
        id: sensorSourceId,
        data: jsonEncode({"type": "FeatureCollection", "features": features}),
      );
      await mapInstance.style.addSource(source);

      if (minSensorValue == maxSensorValue) {
        // For overtaking distnance sensor values, don't set grey for 0 value
        final allowGray = !(widget.sensorType == 'distance');
        final color = sensorColorForValue(
            value: minSensorValue!,
            min: minSensorValue!,
            max: maxSensorValue!,
            allowGray: allowGray);
        await mapInstance.style.addLayer(LineLayer(
          id: sensorLayerId,
          sourceId: sensorSourceId,
          lineColor: color.value,
          lineWidth: 12.0,
          lineCap: LineCap.ROUND,
          lineEmissiveStrength: 1,
        ));
      } else {
        // Multiple values: use color expression
        await mapInstance.style.addLayer(LineLayer(
          id: sensorLayerId,
          sourceId: sensorSourceId,
          lineColorExpression: _sensorColorExpression().cast<Object>(),
          lineWidth: 12.0,
          lineCap: LineCap.ROUND,
          lineEmissiveStrength: 1,
        ));
      }
    } catch (e) {
      debugPrint("Error adding line layer: $e");
    }
  }

  List<Map<String, dynamic>> _buildFeatures() {
    if (widget.geolocationData.isEmpty) return [];
    // Check if all points are the same
    final first = widget.geolocationData.first;
    final allSame = widget.geolocationData.every(
        (g) => g.latitude == first.latitude && g.longitude == first.longitude);

    if (allSame) {
      const offset = 0.000005; // Add a tiny offset to the second point

      return [
        {
          "type": "Feature",
          "properties": {
            for (var sensor in first.sensorData)
              if (!sensor.value.isNaN)
                '${sensor.title}${sensor.attribute == null ? '' : '_${sensor.attribute}'}':
                    sensor.value,
          },
          "geometry": {
            "type": "LineString",
            "coordinates": [
              [first.longitude, first.latitude],
              [first.longitude + offset, first.latitude]
            ],
          },
        }
      ];
    }

    // Default: build features as usual
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

  Future<void> _fitCameraToTrajectory() async {
    try {
      final bounds = await mapInstance.cameraForCoordinateBounds(
        calculateBounds(widget.geolocationData),
        MbxEdgeInsets(top: 16, left: 32, right: 32, bottom: 16),
        0,
        0,
        null,
        null,
      );
      await mapInstance.flyTo(bounds, MapAnimationOptions(duration: 1000));
    } catch (e) {
      debugPrint("Error fitting camera to bounds: $e");
    }
  }

  Future<void> addLayer() async {
    // If sensor values are not available, return early
    if (minSensorValue == double.infinity ||
        maxSensorValue == double.negativeInfinity) {
      debugPrint(
        'TrajectoryWidget: No valid sensor values found for sensorType "${widget.sensorType}". Skipping layer addition.',
      );
      return;
    }
    await _removeLayersAndSources(mapInstance);
    await _addBackgroundLineLayer();
    await _addLineLayer();
    await _fitCameraToTrajectory();
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
        addLayer(); 
      },
    );
  }
}
