import 'dart:convert';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
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
  MapboxMap? _mapInstance;
  bool _mapReady = false;
  bool _disposed = false;
  double? minSensorValue;
  double? maxSensorValue;
  late List<GeolocationData> _mapGeolocations;

  static const String lineSourceId = "lineSource";
  static const String lineLayerBGId = "line_layer_bg";
  static const String sensorLayerId = "sensorLayer";
  static const String sensorSourceId = "sensorSource";

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(mapboxAccessToken);
    _mapGeolocations = downsampleGeolocationsForMapDisplay(widget.geolocationData);
    _updateSensorRange();
  }

  @override
  void didUpdateWidget(TrajectoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensorType != widget.sensorType ||
        oldWidget.geolocationData != widget.geolocationData) {
      _mapGeolocations =
          downsampleGeolocationsForMapDisplay(widget.geolocationData);
      _updateSensorRange();
      addLayer();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cleanupMap();
    super.dispose();
  }

  bool get _canUseMap => mounted && !_disposed && _mapReady && _mapInstance != null;

  void _updateSensorRange() {
    minSensorValue = getMinSensorValue(_mapGeolocations, widget.sensorType);
    maxSensorValue = getMaxSensorValue(_mapGeolocations, widget.sensorType);
  }

  Future<void> _cleanupMap() async {
    final map = _mapInstance;
    if (map == null) return;
    await _removeLayersAndSources(map);
    _mapReady = false;
    _mapInstance = null;
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
    if (!_canUseMap) return;

    final features = _buildFeatures();
    final lineSource = GeoJsonSource(
      id: lineSourceId,
      data: jsonEncode({"type": "FeatureCollection", "features": features}),
    );

    try {
      await _mapInstance!.style.addSource(lineSource);
      if (!_canUseMap) return;
      await _mapInstance!.style.addLayer(LineLayer(
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
    if (widget.sensorType == 'distance') {
      if (minSensorValue == 0.0) {
        return [
          0.0,
          'grey',
          maxSensorValue! * 0.33,
          'red',
          maxSensorValue! * 0.66,
          'orange',
          maxSensorValue!,
          'green'
        ];
      } else {
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
    if (!_canUseMap) return;

    try {
      final features = _buildFeatures();
      final source = GeoJsonSource(
        id: sensorSourceId,
        data: jsonEncode({"type": "FeatureCollection", "features": features}),
      );
      await _mapInstance!.style.addSource(source);
      if (!_canUseMap) return;

      if (minSensorValue == maxSensorValue) {
        final allowGray = !(widget.sensorType == 'distance');
        final color = sensorColorForValue(
            value: minSensorValue!,
            min: minSensorValue!,
            max: maxSensorValue!,
            allowGray: allowGray);
        await _mapInstance!.style.addLayer(LineLayer(
          id: sensorLayerId,
          sourceId: sensorSourceId,
          lineColor: color.value,
          lineWidth: 12.0,
          lineCap: LineCap.ROUND,
          lineEmissiveStrength: 1,
        ));
      } else {
        await _mapInstance!.style.addLayer(LineLayer(
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
    if (_mapGeolocations.isEmpty) return [];
    final first = _mapGeolocations.first;
    final allSame = _mapGeolocations.every(
        (g) => g.latitude == first.latitude && g.longitude == first.longitude);

    if (allSame) {
      const offset = 0.000005;

      return [
        {
          "type": "Feature",
          "properties": {
            for (var sensor in first.sensorData)
              if (!sensor.value.isNaN)
                buildCanonicalSensorKey(sensor.title, sensor.attribute):
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

    return List.generate(_mapGeolocations.length - 1, (index) {
      final current = _mapGeolocations[index];
      final next = _mapGeolocations[index + 1];
      return {
        "type": "Feature",
        "properties": {
          for (var sensor in current.sensorData)
            if (!sensor.value.isNaN)
              buildCanonicalSensorKey(sensor.title, sensor.attribute):
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
    if (!_canUseMap) return;

    try {
      final bounds = await _mapInstance!.cameraForCoordinateBounds(
        calculateBounds(_mapGeolocations),
        MbxEdgeInsets(top: 16, left: 32, right: 32, bottom: 16),
        0,
        0,
        null,
        null,
      );
      if (!_canUseMap) return;
      await _mapInstance!.flyTo(bounds, MapAnimationOptions(duration: 1000));
    } catch (e) {
      debugPrint("Error fitting camera to bounds: $e");
    }
  }

  Future<void> addLayer() async {
    if (!_canUseMap) return;

    if (minSensorValue == double.infinity ||
        maxSensorValue == double.negativeInfinity) {
      debugPrint(
        'TrajectoryWidget: No valid sensor values found for sensorType "${widget.sensorType}". Skipping layer addition.',
      );
      return;
    }

    await _removeLayersAndSources(_mapInstance!);
    if (!_canUseMap) return;
    await _addBackgroundLineLayer();
    if (!_canUseMap) return;
    await _addLineLayer();
    if (!_canUseMap) return;
    await _fitCameraToTrajectory();
  }

  @override
  Widget build(BuildContext context) {
    return ReusableMapWidget(
      logoMargins: const EdgeInsets.all(4),
      attributionMargins: const EdgeInsets.all(4),
      onMapCreated: (mapInstance) async {
        if (_disposed) return;

        _mapInstance = mapInstance;
        _mapReady = true;
        await mapInstance.scaleBar
            .updateSettings(ScaleBarSettings(enabled: false));
        await mapInstance.location.updateSettings(LocationComponentSettings(
          enabled: true,
          showAccuracyRing: true,
        ));
        await addLayer();
      },
    );
  }
}
