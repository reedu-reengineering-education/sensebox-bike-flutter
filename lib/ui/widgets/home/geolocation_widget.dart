import 'dart:async';
import 'dart:convert';

import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_map_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
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
  PolygonAnnotationManager? polygonAnnotationManager;
  StreamSubscription<List<String>>? _privacyZonesSubscription;
  StreamSubscription<GeolocationMapState>? _mapStateSubscription;
  Timer? _trackRenderDebounce;

  // Bloc
  late GeolocationMapBloc _mapBloc;

  // Constants
  static const double authenticatedMargin = 125;
  static const double unauthenticatedMargin = 75;
  static const Duration _trackRenderDebounceDuration =
      Duration(milliseconds: 1200);
  static const Duration _cameraUpdateInterval = Duration(seconds: 2);
  static const double _cameraMinDistanceMeters = 3;
  static const Duration _maxTrackRenderInterval = Duration(seconds: 3);
  static const int _minNewPointsPerTrackRender = 3;
  bool _isVisible = true;
  bool _isMapReady = false;
  int _lastRenderedPointCount = 0;
  DateTime? _lastCameraUpdateAt;
  DateTime? _lastTrackRenderAt;
  GeolocationData? _lastCameraLocation;
  bool? _lastAuthStateForMargins;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMapBloc();
    _setupMapBlocListener();
    _setupPrivacyZonesListener();
  }

  void _initializeMapBloc() {
    _mapBloc = GeolocationMapBloc(
      geolocationBloc: context.read<GeolocationBloc>(),
      recordingBloc: context.read<RecordingBloc>(),
      osemBloc: context.read<OpenSenseMapBloc>(),
    );
  }

  void _setupMapBlocListener() {
    _mapStateSubscription = _mapBloc.stream.listen(_onMapBlocChanged);
  }

  void _onMapBlocChanged(GeolocationMapState state) {
    if (!mounted || !_isVisible) return;

    if (_lastAuthStateForMargins != state.isAuthenticated) {
      _lastAuthStateForMargins = state.isAuthenticated;
      _updateMapMargins();
    }

    // Recording path updates are expensive, so debounce redraws.
    if (state.isRecording && state.gpsBuffer.isNotEmpty) {
      if (_shouldRenderTrack(state.gpsBuffer.length)) {
        _scheduleTrackRender();
      }
      return;
    }

    // Clear track once when recording stopped.
    if (!state.isRecording &&
        _lastRenderedPointCount > 0 &&
        state.gpsBuffer.isEmpty) {
      _lastRenderedPointCount = 0;
      _lastTrackRenderAt = null;
      _clearTrackLine();
    }

    // Idle location camera updates are throttled to avoid jank.
    if (!state.isRecording && state.latestLocation != null) {
      _showCurrentLocation(state.latestLocation!);
    }
  }

  void _scheduleTrackRender() {
    _trackRenderDebounce?.cancel();
    _trackRenderDebounce =
        Timer(_trackRenderDebounceDuration, _updateMapWithTrack);
  }

  bool _shouldRenderTrack(int currentPointCount) {
    final newPoints = currentPointCount - _lastRenderedPointCount;
    if (newPoints <= 0) return false;
    if (newPoints >= _minNewPointsPerTrackRender) return true;

    final lastRenderAt = _lastTrackRenderAt;
    if (lastRenderAt == null) return true;

    return DateTime.now().difference(lastRenderAt) >= _maxTrackRenderInterval;
  }

  void _updateMapMargins() {
    if (!_isMapReady) return;
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
    if (!_isMapReady) return;
    lineAnnotationManager.deleteAll().catchError((e) {
      // Ignore errors when clearing track line
    });
  }

  // Map Update Methods
  void _updateMapWithTrack() async {
    if (!_isMapReady || _mapBloc.gpsBuffer.isEmpty) return;

    try {
      _clearTrackLine();
      final points = _createTrackPoints();
      if (points.isEmpty) return;

      await _drawTrackLine(points);
      _lastRenderedPointCount = _mapBloc.gpsBuffer.length;
      _lastTrackRenderAt = DateTime.now();
      await _setCameraToLastLocation(force: true);
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

  Future<void> _setCameraToLastLocation({bool force = false}) async {
    final lastLocation = _mapBloc.lastLocationForMap;
    if (lastLocation == null) return;

    await _setCameraToLocation(lastLocation, force: force);
  }

  void _showCurrentLocation(GeolocationData geoData) async {
    try {
      await _setCameraToLocation(geoData);
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
    }
  }

  bool _shouldSkipCameraUpdate(GeolocationData location) {
    final now = DateTime.now();
    if (_lastCameraUpdateAt != null &&
        now.difference(_lastCameraUpdateAt!) < _cameraUpdateInterval) {
      return true;
    }

    if (_lastCameraLocation == null) {
      return false;
    }

    final distance = geolocator.Geolocator.distanceBetween(
      _lastCameraLocation!.latitude,
      _lastCameraLocation!.longitude,
      location.latitude,
      location.longitude,
    );
    return distance < _cameraMinDistanceMeters;
  }

  Future<void> _setCameraToLocation(GeolocationData location,
      {bool force = false}) async {
    if (!_isMapReady) return;
    if (!force && _shouldSkipCameraUpdate(location)) return;

    final cameraOptions = CameraOptions(
      center:
          Point(coordinates: Position(location.longitude, location.latitude)),
      zoom: 16.0,
      pitch: 45,
    );

    // Use setCamera instead of flyTo for immediate positioning
    await mapInstance?.setCamera(cameraOptions);
    _lastCameraUpdateAt = DateTime.now();
    _lastCameraLocation = location;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _privacyZonesSubscription?.cancel();
    _mapStateSubscription?.cancel();
    _trackRenderDebounce?.cancel();
    unawaited(_mapBloc.close());
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
          isDark ? Colors.white.toARGB32() : Colors.black.toARGB32());
      lineAnnotationManager.setLineWidth(4.0);
      lineAnnotationManager.setLineEmissiveStrength(1);
      lineAnnotationManager.setLineCap(LineCap.ROUND);

      polygonAnnotationManager = await mapInstance!.annotations
          .createPolygonAnnotationManager(id: 'privacyZonesManager');
      polygonAnnotationManager!.setFillColor(Colors.red.toARGB32());
      polygonAnnotationManager!.setFillOpacity(0.5);
      polygonAnnotationManager!.setFillEmissiveStrength(1);

      // Enable location puck if location permissions are granted
      final hasPermission =
          await PermissionService.isLocationPermissionGranted();
      if (hasPermission && mounted) {
        mapInstance?.location.updateSettings(LocationComponentSettings(
          enabled: true,
          showAccuracyRing: true,
        ));
      }
      _isMapReady = true;
      _updateMapMargins();
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
    }
  }

  void _setupPrivacyZonesListener() {
    final settingsBloc = context.read<SettingsBloc>();
    _privacyZonesSubscription = settingsBloc.privacyZonesStream.listen((zones) {
      if (mounted && mapInstance != null) {
        _updatePrivacyZones();
      }
    });
  }

  Future<void> _addPrivacyZones() async {
    await _updatePrivacyZones();
  }

  Future<void> _updatePrivacyZones() async {
    try {
      if (mapInstance == null || polygonAnnotationManager == null) return;

      final settingsBloc = context.read<SettingsBloc>();

      await polygonAnnotationManager!.deleteAll().catchError((e) {
        // Ignore errors when clearing privacy zones
      });

      if (settingsBloc.privacyZones.isEmpty) return;

      final polygonOptions = settingsBloc.privacyZones.map((e) {
        final polygon = Polygon.fromJson(jsonDecode(e));
        return PolygonAnnotationOptions(geometry: polygon);
      }).toList();

      await polygonAnnotationManager!.createMulti(polygonOptions);
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
    }
  }
}
