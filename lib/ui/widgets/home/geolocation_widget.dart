import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';
import 'package:easy_debounce/easy_debounce.dart';

class GeolocationMapWidget extends StatefulWidget {
  const GeolocationMapWidget({super.key});

  @override
  State<GeolocationMapWidget> createState() => _GeolocationMapWidgetState();
}

class _GeolocationMapWidgetState extends State<GeolocationMapWidget> {
  late final MapboxMap mapInstance;
  StreamSubscription<GeolocationData>? _gpsSubscription;
  VoidCallback? _recordingListener;

  late PolylineAnnotationManager lineAnnotationManager;

  late OpenSenseMapBloc osemBloc;

  // Local buffer for GPS data during recording
  final List<GeolocationData> _gpsBuffer = [];
  bool _isRecording = false;

  static const double authenticatedMargin = 125;
  static const double unauthenticatedMargin = 75;

  @override
  void initState() {
    super.initState();
    
    _isRecording = context.read<RecordingBloc>().isRecording;
    _recordingListener = () {
      final newRecordingState = context.read<RecordingBloc>().isRecording;

      if (_isRecording && !newRecordingState) {
        _clearGpsBuffer();
      }
      
      _isRecording = newRecordingState;
    };
    context
        .read<RecordingBloc>()
        .isRecordingNotifier
        .addListener(_recordingListener!);

    _startListeningToGPS();

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
              ? await geolocator.Geolocator.getCurrentPosition()
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

  void _startListeningToGPS() {
    final geolocationBloc = context.read<GeolocationBloc>();

    _gpsSubscription = geolocationBloc.geolocationStream.listen((geoData) {
      if (geoData.latitude == 0.0 && geoData.longitude == 0.0) {
        return;
      }

      if (_isRecording) {
        _addToGpsBuffer(geoData);
        _updateMapWithTrack();
      } else {
        _showCurrentLocation(geoData);
      }
    });
  }

  void _addToGpsBuffer(GeolocationData geoData) {
    // Check if this point already exists in buffer (avoid duplicates)
    final existingPoint = _gpsBuffer
        .where((point) =>
            point.latitude == geoData.latitude &&
            point.longitude == geoData.longitude &&
            point.timestamp == geoData.timestamp)
        .firstOrNull;

    if (existingPoint == null) {
      _gpsBuffer.add(geoData);
    } 
  }

  void _clearGpsBuffer() {
    _gpsBuffer.clear();
    _clearTrackLine();
  }

  void _clearTrackLine() {
    lineAnnotationManager.deleteAll().catchError((e) {
      debugPrint('Error clearing track line: $e');
    });
  }

  void _updateMapWithTrack() async {
    if (_gpsBuffer.isEmpty) {
      return;
    }

    try {
      _clearTrackLine();

      List<Point> points = _gpsBuffer.map((location) {
        return Point(
            coordinates: Position(location.longitude, location.latitude));
      }).toList();

      if (points.isEmpty) {
        return;
      }

      if (points.length == 1) {
        final singlePoint = points.first;
        final offset = 0.00001; 

        points = [
          singlePoint,
          Point(
              coordinates: Position(singlePoint.coordinates.lng + offset,
                  singlePoint.coordinates.lat + offset))
        ];
      }

      PolylineAnnotationOptions polyline = PolylineAnnotationOptions(
        geometry: LineString.fromPoints(points: points),
      );
      await lineAnnotationManager.create(polyline);
      // Fly to the last GPS position
      GeolocationData lastLocation = _gpsBuffer.last;
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
      debugPrint('Error updating map with track: $e');
    }
  }

  void _showCurrentLocation(GeolocationData geoData) async {
    try {
      await mapInstance.flyTo(
          CameraOptions(
            center: Point(
                coordinates: Position(geoData.longitude, geoData.latitude)),
            zoom: 16.0,
            pitch: 45,
          ),
          MapAnimationOptions(duration: 1000));
    } catch (e) {
      debugPrint('Error updating map with current location: $e');
    }
  }

  @override
  void dispose() {
    EasyDebounce.cancel(
        'map_update_${context.read<TrackBloc>().currentTrack?.id ?? 0}');
    _gpsSubscription?.cancel();
    if (_recordingListener != null) {
      context
          .read<RecordingBloc>()
          .isRecordingNotifier
          .removeListener(_recordingListener!);
    }
    // Clear buffer to free memory
    _gpsBuffer.clear();
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
          
          // Capture theme before async operations
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          try {
            lineAnnotationManager = await mapInstance.annotations
                .createPolylineAnnotationManager(id: 'lineAnnotationManager');
            lineAnnotationManager.setLineColor(
                isDark ? Colors.white.toARGB32() : Colors.black.toARGB32());
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
            polygonAnnotationManager.setFillColor(Colors.red.toARGB32());
            polygonAnnotationManager.setFillOpacity(0.5);
            polygonAnnotationManager.setFillEmissiveStrength(1);

            final polygonOptions = settingsBloc.privacyZones.map((e) {
              final polygon = Polygon.fromJson(jsonDecode(e));
              return PolygonAnnotationOptions(geometry: polygon);
            }).toList();
            polygonAnnotationManager.createMulti(polygonOptions);
          } catch (e) {
            debugPrint('Error adding privacy zones: $e');
          }
        });
  }
}
