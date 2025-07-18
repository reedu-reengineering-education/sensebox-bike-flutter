import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart' as Geolocator;
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
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
import 'package:easy_debounce/easy_debounce.dart';

class GeolocationMapWidget extends StatefulWidget {
  const GeolocationMapWidget({super.key});

  @override
  _GeolocationMapWidgetState createState() => _GeolocationMapWidgetState();
}

class _GeolocationMapWidgetState extends State<GeolocationMapWidget> {
  late final MapboxMap mapInstance;
  StreamSubscription? _isarGeolocationSubscription;
  StreamSubscription<TrackData?>? _trackSubscription;

  late PolylineAnnotationManager lineAnnotationManager;

  late OpenSenseMapBloc osemBloc;

  static const double authenticatedMargin = 125;
  static const double unauthenticatedMargin = 75;

  @override
  void initState() {
    super.initState();
    // Listen to track changes from the TrackBloc
    _trackSubscription =
        context.read<TrackBloc>().currentTrackStream.listen((track) async {
      if (!mounted) return; 
      
      if (track != null) {
        _isarGeolocationSubscription =
            await _listenToGeolocationStream(track.id);
      } else {
        // Clear annotations when no track is active
        try {
          await lineAnnotationManager.deleteAll();
        } catch (e) {
          debugPrint('Error clearing annotations when no track: $e');
        }
      }
    });

    // Listen to authentication state changes
    // This will update the map's logo and attribution margins based on authentication state
    // Not authenticated: no select box dialog shown ==> margin bottom 75
    // Authenticated: select box dialog shown ==> margin bottom 125
    osemBloc = Provider.of<OpenSenseMapBloc>(context, listen: false);
    osemBloc.addListener(() {
      final isAuthenticated = osemBloc.isAuthenticated;

      var logoAttributionMargins = EdgeInsets.only(
        bottom: isAuthenticated ? authenticatedMargin : unauthenticatedMargin,
        left: 8,
        right: 8,
      );

      mapInstance.logo.updateSettings(
        LogoSettings(
          marginBottom: logoAttributionMargins.bottom,
          marginLeft: logoAttributionMargins.left,
        ),
      );
      mapInstance.attribution.updateSettings(
        AttributionSettings(
          marginBottom: logoAttributionMargins.bottom,
          marginRight: logoAttributionMargins.right,
        ),
      );
    });

    // check connection status
    context.read<BleBloc>().isConnectingNotifier.addListener(() async {
      if (!mounted) return;
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
      try {
        EasyDebounce.debounce(
          'map_update_$trackId',
          const Duration(milliseconds: 500),
          () async {
            try {
              List<GeolocationData> geoData = await isarService
                  .geolocationService
                  .getGeolocationDataByTrackId(trackId);

              if (geoData.isNotEmpty) {
                _updateMapWithGeolocationData(geoData);
              }
            } catch (e) {
              debugPrint('Error in debounced map update: $e');
            }
          },
        );
      } catch (e) {
        debugPrint('Error in geolocation stream listener: $e');
        // Don't rethrow to prevent stream cancellation
      }
    }).onError((error) {
      debugPrint('Geolocation stream error: $error');
    });
  }

  void _updateMapWithGeolocationData(List<GeolocationData> geoData) async {
    try {
      try {
        await lineAnnotationManager.deleteAll();
      } catch (e) {
        // Ignore errors when deleting annotations - this can happen when there are no annotations to delete
        debugPrint('Note: No existing annotations to delete: $e');
      }

      List<Point> points = geoData.map((location) {
        return Point(
            coordinates: Position(location.longitude, location.latitude));
      }).toList();

      if (points.isEmpty) {
        return;
      }

      if (points.length == 1) {
        final singlePoint = points.first;
        final offset = 0.00001; // Small offset for visibility

        points = [
          singlePoint,
          Point(
              coordinates: Position(singlePoint.coordinates.lng + offset,
                  singlePoint.coordinates.lat + offset))
        ];
      }

      if (points.length < 2) {
        return;
      }

      PolylineAnnotationOptions polyline = PolylineAnnotationOptions(
        geometry: LineString.fromPoints(points: points),
      );

      await lineAnnotationManager.create(polyline);
      GeolocationData lastLocation = geoData.last;
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
      // Don't rethrow the error to prevent app crashes
    }
  }

  @override
  void dispose() {
    EasyDebounce.cancel(
        'map_update_${context.read<TrackBloc>().currentTrack?.id ?? 0}');
    _isarGeolocationSubscription?.cancel();
    _trackSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsBloc = Provider.of<SettingsBloc>(context);

    final isAuthenticated = osemBloc.isAuthenticated;

    var logoAttributionMargins = EdgeInsets.only(
      bottom: isAuthenticated ? authenticatedMargin : unauthenticatedMargin,
      left: 8,
      right: 8,
    );

    return ReusableMapWidget(
        logoMargins: logoAttributionMargins,
        attributionMargins: logoAttributionMargins,
        onMapCreated: (mapInstance) async {
          this.mapInstance = mapInstance;
          mapInstance.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
          mapInstance.compass.updateSettings(CompassSettings(enabled: false));

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
