import 'dart:async';
import 'dart:convert';

import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_map_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';

class GeolocationMapWidget extends StatefulWidget {
  const GeolocationMapWidget({super.key});

  @override
  State<GeolocationMapWidget> createState() => _GeolocationMapWidgetState();
}

class _GeolocationMapWidgetState extends State<GeolocationMapWidget>
    with WidgetsBindingObserver {
  // Map instances
  MapboxMap? mapInstance;
  late PolylineAnnotationManager lineAnnotationManager;

  // Bloc
  late GeolocationMapBloc _mapBloc;

  // Constants
  static const double authenticatedMargin = 125;
  static const double unauthenticatedMargin = 75;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMapBloc();
    _setupMapBlocListener();
  }

  void _initializeMapBloc() {
    _mapBloc = GeolocationMapBloc(
      geolocationBloc: context.read<GeolocationBloc>(),
      recordingBloc: context.read<RecordingBloc>(),
      osemBloc: context.read<OpenSenseMapBloc>(),
    );
  }

  void _setupMapBlocListener() {
    _mapBloc.addListener(_onMapBlocChanged);
  }

  void _onMapBlocChanged() {
    if (!mounted || !_isVisible) return;
    
    // Update map based on bloc state
    if (_mapBloc.shouldShowTrack) {
      _updateMapWithTrack();
    } else if (_mapBloc.shouldShowCurrentLocation) {
      _showCurrentLocation(_mapBloc.latestLocation!);
    }
    
    // Update margins
    _updateMapMargins();
  }

  void _updateMapMargins() {
    final isAuthenticated = _mapBloc.isAuthenticated;

    var logoAttributionMargins = EdgeInsets.only(
      bottom: isAuthenticated ? authenticatedMargin : unauthenticatedMargin,
      left: 8,
      right: 8,
    );

    mapInstance?.logo.updateSettings(
      LogoSettings(
        marginBottom: logoAttributionMargins.bottom,
        marginLeft: logoAttributionMargins.left,
      ),
    );
    mapInstance?.attribution.updateSettings(
      AttributionSettings(
        marginBottom: logoAttributionMargins.bottom,
        marginRight: logoAttributionMargins.right,
      ),
    );
  }

  // Map Management
  void _clearTrackLine() {
    lineAnnotationManager.deleteAll().catchError((e) {
      // Ignore errors when clearing track line
    });
  }

  // Map Update Methods
  void _updateMapWithTrack() async {
    if (_mapBloc.gpsBuffer.isEmpty) return;

    try {
      _clearTrackLine();
      final points = _createTrackPoints();
      if (points.isEmpty) return;

      await _drawTrackLine(points);
      await _setCameraToLastLocation();
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
    }
  }

  List<Point> _createTrackPoints() {
    List<Point> points = _mapBloc.gpsBuffer.map((location) {
      return Point(
          coordinates: Position(location.longitude, location.latitude));
    }).toList();

    if (points.isEmpty) return [];

    // Create a line segment for single points
    if (points.length == 1) {
      final singlePoint = points.first;
      final offset = 0.00001;
      points = [
        singlePoint,
        Point(
            coordinates: Position(
          singlePoint.coordinates.lng + offset,
          singlePoint.coordinates.lat + offset,
        ))
      ];
    }

    return points;
  }

  Future<void> _drawTrackLine(List<Point> points) async {
    if (points.length < 2) return;

    final polyline = PolylineAnnotationOptions(
      geometry: LineString.fromPoints(points: points),
    );
    await lineAnnotationManager.create(polyline);
  }

  Future<void> _setCameraToLastLocation() async {
    final lastLocation = _mapBloc.lastLocationForMap;
    if (lastLocation == null) return;

    await _setCameraToLocation(lastLocation);
  }

  void _showCurrentLocation(GeolocationData geoData) async {
    try {
      await _setCameraToLocation(geoData);
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
    }
  }

  Future<void> _setCameraToLocation(GeolocationData location) async {
    final cameraOptions = CameraOptions(
      center:
          Point(coordinates: Position(location.longitude, location.latitude)),
      zoom: 16.0,
      pitch: 45,
    );

    // Use setCamera instead of flyTo for immediate positioning
    await mapInstance?.setCamera(cameraOptions);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapBloc.removeListener(_onMapBlocChanged);
    _mapBloc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isVisible = (state == AppLifecycleState.resumed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final margins = _getMapMargins();

    return ReusableMapWidget(
      logoMargins: margins,
      attributionMargins: margins,
      onMapCreated: _onMapCreated,
    );
  }

  EdgeInsets _getMapMargins() {
    final isAuthenticated = _mapBloc.isAuthenticated;
    return EdgeInsets.only(
      bottom: isAuthenticated ? authenticatedMargin : unauthenticatedMargin,
      left: 8,
      right: 8,
    );
  }

  void _onMapCreated(MapboxMap mapInstance) async {
    this.mapInstance = mapInstance;
    _configureMapSettings();
    await _setupMapComponents();
    await _addPrivacyZones();
  }

  void _configureMapSettings() {
    mapInstance?.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    mapInstance?.compass.updateSettings(CompassSettings(enabled: false));

    // Set initial camera position
    mapInstance?.setCamera(CameraOptions(
      center: Point(coordinates: Position(9, 45)),
      zoom: 3.25,
      pitch: 25,
    ));
  }

  Future<void> _setupMapComponents() async {
    try {
      lineAnnotationManager = await mapInstance!.annotations
          .createPolylineAnnotationManager(id: 'lineAnnotationManager');
      
      // Store brightness before async operation to avoid context gap
      final isDark = Theme.of(context).brightness == Brightness.dark;
      lineAnnotationManager.setLineColor(
          isDark ? Colors.white.value : Colors.black.value);
      lineAnnotationManager.setLineWidth(4.0);
      lineAnnotationManager.setLineEmissiveStrength(1);
      lineAnnotationManager.setLineCap(LineCap.ROUND);

      // Enable location puck if location permissions are granted
      final hasPermission =
          await PermissionService.isLocationPermissionGranted();
      if (hasPermission && mounted) {
        mapInstance?.location.updateSettings(LocationComponentSettings(
          enabled: true,
          showAccuracyRing: true,
        ));
      }
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
    }
  }

  Future<void> _addPrivacyZones() async {
    try {
      final settingsBloc = Provider.of<SettingsBloc>(context, listen: false);
      if (settingsBloc.privacyZones.isEmpty) return;

      final polygonAnnotationManager =
          await mapInstance!.annotations.createPolygonAnnotationManager();
      polygonAnnotationManager.setFillColor(Colors.red.toARGB32());
      polygonAnnotationManager.setFillOpacity(0.5);
      polygonAnnotationManager.setFillEmissiveStrength(1);

      final polygonOptions = settingsBloc.privacyZones.map((e) {
        final polygon = Polygon.fromJson(jsonDecode(e));
        return PolygonAnnotationOptions(geometry: polygon);
      }).toList();
      polygonAnnotationManager.createMulti(polygonOptions);
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
    }
  }
}
