import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart' as Geolocator;
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';
import '../../../blocs/track_bloc.dart'; // Import TrackBloc
import '../../../services/isar_service.dart'; // Import your Isar service

class GeolocationMapWidget extends StatefulWidget {
  const GeolocationMapWidget({super.key});

  @override
  _GeolocationMapWidgetState createState() => _GeolocationMapWidgetState();
}

class _GeolocationMapWidgetState extends State<GeolocationMapWidget> {
  late final MapboxMap mapInstance;
  StreamSubscription? _isarGeolocationSubscription;
  StreamSubscription<TrackData?>? _trackSubscription; // Track ID subscription

  late PolylineAnnotationManager lineAnnotationManager;

  final isarService = IsarService();

  @override
  void initState() {
    super.initState();
    // Listen to track changes from the TrackBloc
    _trackSubscription =
        context.read<TrackBloc>().currentTrackStream.listen((track) async {
      // Handle trackId changes
      if (track != null) {
        _isarGeolocationSubscription =
            await _listenToGeolocationStream(track.id);
      } else {
        await lineAnnotationManager.deleteAll();
      }
    });

    // check connection status
    context.read<BleBloc>().isConnectingNotifier.addListener(() async {
      bool enableLocationPuck = context.read<BleBloc>().isConnected;
      mapInstance.location.updateSettings(LocationComponentSettings(
        enabled: enableLocationPuck,
        showAccuracyRing: enableLocationPuck,
      ));
      if (enableLocationPuck) {
        var geoPosition = await Geolocator.Geolocator.getCurrentPosition();
        await mapInstance.flyTo(
            CameraOptions(
              center: Point(
                  coordinates:
                      Position(geoPosition.longitude, geoPosition.latitude)),
              zoom: 16.0,
              pitch: 45,
            ),
            MapAnimationOptions(duration: 1000));
      }
    });
  }

  // Listen to the Isar geolocation stream and update the map
  Future _listenToGeolocationStream(int trackId) async {
    // Access the geolocation stream from the service
    return (await isarService.geolocationService.getGeolocationStream())
        .listen((_) async {
      // Fetch geolocation data for the given track ID
      List<GeolocationData> geoData = await isarService.geolocationService
          .getGeolocationDataByTrackId(trackId);

      // If geolocation data is available, update the map source and layer
      if (geoData.isNotEmpty) {
        _updateMapWithGeolocationData(geoData);
      }
    });
  }

  // Create or update the map source with new geolocation data
  void _updateMapWithGeolocationData(List<GeolocationData> geoData) async {
    lineAnnotationManager.deleteAll();

    List<Point> points = geoData.map((location) {
      return Point(
          coordinates: Position(location.longitude, location.latitude));
    }).toList();

    PolylineAnnotationOptions polyline = PolylineAnnotationOptions(
      geometry: LineString.fromPoints(points: points),
    );

    lineAnnotationManager.create(polyline);

    // get last geolocation data
    GeolocationData lastLocation = geoData.last;

    // Fit the camera to the bounds of the geolocation data
    await mapInstance.flyTo(
        CameraOptions(
          center: Point(
              coordinates:
                  Position(lastLocation.longitude, lastLocation.latitude)),
          zoom: 16.0,
          pitch: 45,
        ),
        MapAnimationOptions(duration: 1000));
  }

  @override
  void dispose() {
    _isarGeolocationSubscription?.cancel();
    _trackSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsBloc = Provider.of<SettingsBloc>(context);

    return ReusableMapWidget(onMapCreated: (mapInstance) async {
      this.mapInstance = mapInstance;
      mapInstance.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
      mapInstance.compass.updateSettings(CompassSettings(enabled: false));
      mapInstance.attribution
          .updateSettings(AttributionSettings(marginBottom: 75));
      mapInstance.logo
          .updateSettings(LogoSettings(marginBottom: 75, marginLeft: 8));

      // Set initial camera position
      mapInstance.setCamera(CameraOptions(
        center: Point(coordinates: Position(9, 45)),
        zoom: 3.25,
        pitch: 25,
      ));

      lineAnnotationManager = await mapInstance.annotations
          .createPolylineAnnotationManager(id: 'lineAnnotationManager');
      lineAnnotationManager.setLineColor(
          Theme.of(context).brightness == Brightness.dark
              ? Colors.white.value
              : Colors.black.value);
      lineAnnotationManager.setLineWidth(4.0);
      lineAnnotationManager.setLineEmissiveStrength(1);
      lineAnnotationManager.setLineCap(LineCap.ROUND);

      // Add privacy zones to the map
      try {
        if (settingsBloc.privacyZones.isEmpty) {
          return;
        }

        final polygonAnnotationManager =
            await mapInstance.annotations.createPolygonAnnotationManager();
        polygonAnnotationManager.setFillColor(Colors.red.value);
        polygonAnnotationManager.setFillOpacity(0.5);
        polygonAnnotationManager.setFillEmissiveStrength(1);

        final polygonOptions = settingsBloc.privacyZones.map((e) {
          final polygon = Polygon.fromJson(jsonDecode(e));
          return PolygonAnnotationOptions(geometry: polygon);
        }).toList();
        polygonAnnotationManager.createMulti(polygonOptions);
      } catch (e) {
        print(e);
      }
    });
  }
}
