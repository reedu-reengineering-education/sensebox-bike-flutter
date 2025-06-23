import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart' as Geolocator;
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';

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

  @override
  void initState() {
    super.initState();
    // Listen to track changes from the TrackBloc
    _trackSubscription =
        context.read<TrackBloc>().currentTrackStream.listen((track) async {
      if (!mounted) return; // Check if the widget is still mounted
      // Handle trackId changes
      if (track != null) {
        _isarGeolocationSubscription =
            await _listenToGeolocationStream(track.id);
      } else {
        try {
          await lineAnnotationManager.deleteAll();
        } catch (e) {
          debugPrint('Error deleting all annotations: $e');
        }
      }
    });

    // check connection status
    context.read<BleBloc>().isConnectingNotifier.addListener(() async {
      if (!mounted) return; // Check if the widget is still mounted
      bool enableLocationPuck = context.read<BleBloc>().isConnected;
      mapInstance.location.updateSettings(LocationComponentSettings(
        enabled: enableLocationPuck,
        showAccuracyRing: enableLocationPuck,
      ));
      if (enableLocationPuck) {
        if (!mounted) return;
        try {
          final hasPermission =
              await PermissionService.isLocationPermissionGranted();
          final geoPosition = hasPermission
              ? await Geolocator.Geolocator.getCurrentPosition()
              : globePosition;
          final isGlobe =
              geoPosition.latitude == 0.0 && geoPosition.longitude == 0.0;
          final cameraOptions = CameraOptions(
            center: Point(
              coordinates:
                  Position(geoPosition.longitude, geoPosition.latitude),
            ),
            zoom: isGlobe ? 1.5 : defaultCameraOptions['zoom'],
            pitch: defaultCameraOptions['pitch'],
          );
          final animationOptions = MapAnimationOptions(duration: 1000);

          await mapInstance.flyTo(cameraOptions, animationOptions);
        } catch (e, stack) {
          ErrorService.handleError(e, stack);
        }
      }
    });
  }

  Future _listenToGeolocationStream(int trackId) async {
    final isarService = context.read<TrackBloc>().isarService;
    return (await isarService.geolocationService.getGeolocationStream())
        .listen((_) async {
      List<GeolocationData> geoData = await isarService.geolocationService
          .getGeolocationDataByTrackId(trackId);

      // If geolocation data is available, update the map source and layer
      if (geoData.isNotEmpty) {
        _updateMapWithGeolocationData(geoData);
      }
    }).onError((error) {
      ErrorService.handleError(error, StackTrace.current);
    });
  }

  // Create or update the map source with new geolocation data
  void _updateMapWithGeolocationData(List<GeolocationData> geoData) async {
    try {
      // Delete existing annotations if any
      await lineAnnotationManager.deleteAll();

      List<Point> points = geoData.map((location) {
        return Point(
            coordinates: Position(location.longitude, location.latitude));
      }).toList();

      // Ensure there are at least two points before creating the LineString
      if (points.length < 2) {
        debugPrint('Not enough points to create a LineString.');
        return;
      }

      PolylineAnnotationOptions polyline = PolylineAnnotationOptions(
        geometry: LineString.fromPoints(points: points),
      );

      await lineAnnotationManager.create(polyline);

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
    } catch (e) {
      debugPrint('Error updating map with geolocation data: $e');
    }
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
      try {
        lineAnnotationManager = await mapInstance.annotations
          .createPolylineAnnotationManager(id: 'lineAnnotationManager');
        lineAnnotationManager.setLineColor(
            Theme.of(context).brightness == Brightness.dark
                ? Colors.white.value
                : Colors.black.value);
        lineAnnotationManager.setLineWidth(4.0);
        lineAnnotationManager.setLineEmissiveStrength(1);
        lineAnnotationManager.setLineCap(LineCap.ROUND);
      } catch (e) {
        debugPrint('Error creating lineAnnotationManager: $e');
      }

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
