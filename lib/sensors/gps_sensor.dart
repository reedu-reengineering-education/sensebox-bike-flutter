import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_card.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class GPSSensor extends Sensor {
  static int get staticUiPriority => 60;

  @override
  int get uiPriority => staticUiPriority;

  static const String sensorCharacteristicUuid =
      '8edf8ebb-1246-4329-928d-ee0c91db2389';

  GPSSensor(
    BleBloc bleBloc,
    GeolocationBloc geolocationBloc,
    RecordingBloc recordingBloc,
    IsarService isarService,
  ) : super(
          sensorCharacteristicUuid,
          'sensor_gps',
          const ['latitude', 'longitude', 'speed'],
          bleBloc,
          geolocationBloc,
          recordingBloc,
          isarService,
        );

  @override
  List<double> aggregateData(List<List<double>> valueBuffer) {
    final sumValues = [0.0, 0.0, 0.0];
    final count = valueBuffer.length;

    for (final values in valueBuffer) {
      sumValues[0] += values[0];
      sumValues[1] += values[1];
      sumValues[2] += values[2];
    }

    return sumValues.map((value) => value / count).toList();
  }

  @override
  Widget buildWidget() {
    return _GpsMapWidget(valueStream: valueStream, initialValue: latestValue);
  }
}

class _GpsMapWidget extends StatefulWidget {
  const _GpsMapWidget({
    required this.valueStream,
    required this.initialValue,
  });

  final Stream<List<double>> valueStream;
  final List<double> initialValue;

  @override
  State<_GpsMapWidget> createState() => _GpsMapWidgetState();
}

class _GpsMapWidgetState extends State<_GpsMapWidget> {
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
      if (value.length < 2) return;
      if (!mounted) return;
      setState(() {
        _lat = value[0];
        _lng = value[1];
      });
      _updateMarkerAndCamera();
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
