import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class GpsSensorTile extends StatefulWidget {
  const GpsSensorTile({
    required this.valueStream,
    required this.initialValue,
    super.key,
  });

  final Stream<List<double>> valueStream;
  final List<double> initialValue;

  @override
  State<GpsSensorTile> createState() => _GpsSensorTileState();
}

class _GpsSensorTileState extends State<GpsSensorTile> {
  StreamSubscription<List<double>>? _subscription;
  MapboxMap? _map;
  CircleAnnotationManager? _circleManager;

  double _lat = 0.0;
  double _lng = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue.length >= 2) {
      _lat = widget.initialValue[0];
      _lng = widget.initialValue[1];
    }

    _subscription = widget.valueStream.listen((value) {
      if (value.length >= 2) {
        _lat = value[0];
        _lng = value[1];
        _updateMarkerAndCamera();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _updateMarkerAndCamera() async {
    final map = _map;
    final manager = _circleManager;

    if (map == null || manager == null) return;
    if (_lat == 0.0 && _lng == 0.0) return;

    try {
      await manager.deleteAll();
      manager.setCirclePitchAlignment(CirclePitchAlignment.MAP);
      manager.setCircleEmissiveStrength(1);

      final marker = CircleAnnotationOptions(
        geometry: Point(coordinates: Position(_lng, _lat)),
        circleColor: Colors.blue.toARGB32(),
        circleRadius: 8,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2,
      );

      await manager.createMulti([marker]);
      await map.flyTo(
        CameraOptions(
          zoom: 16.0,
          pitch: 45,
          center: Point(coordinates: Position(_lng, _lat)),
        ),
        MapAnimationOptions(duration: 1000),
      );
    } catch (_) {
      // Keep UI resilient if map style/annotation state changes rapidly.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lat == 0.0 && _lng == 0.0) {
      return SensorCard(
        icon: getSensorIcon('gps'),
        color: getSensorColor('gps'),
        title: 'GPS',
        child: Center(
          child: Text(AppLocalizations.of(context)!.sensorGPSError),
        ),
      );
    }

    return Card(
      elevation: 1,
      clipBehavior: Clip.hardEdge,
      child: ReusableMapWidget(
        logoMargins: const EdgeInsets.all(4),
        attributionMargins: const EdgeInsets.all(4),
        onMapCreated: (map) {
          _map = map;
          _updateMarkerAndCamera();
        },
        onStyleLoadedCallback: (map) async {
          _circleManager ??=
              await map.annotations.createCircleAnnotationManager();
          _updateMarkerAndCamera();
        },
      ),
    );
  }
}
