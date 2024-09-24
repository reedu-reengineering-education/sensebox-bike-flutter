import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart' as Geolocator;
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/models/track_data.dart';
import '../../../blocs/track_bloc.dart'; // Import TrackBloc
import '../../../secrets.dart'; // File containing the Mapbox token
import '../../../services/isar_service.dart'; // Import your Isar service

class GeolocationMapWidget extends StatefulWidget {
  const GeolocationMapWidget({super.key});

  @override
  _GeolocationMapWidgetState createState() => _GeolocationMapWidgetState();
}

class _GeolocationMapWidgetState extends State<GeolocationMapWidget>
    with WidgetsBindingObserver {
  late final MapboxMap mapInstance;
  StreamSubscription<List<GeolocationData>>? _isarGeolocationSubscription;
  StreamSubscription<TrackData?>? _trackSubscription; // Track ID subscription

  final isarService = IsarService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set the access token for Mapbox
    MapboxOptions.setAccessToken(mapboxAccessToken);

    // Listen to track changes from the TrackBloc
    _trackSubscription =
        context.read<TrackBloc>().currentTrackStream.listen((track) {
      // Handle trackId changes
      if (track != null) {
        _isarGeolocationSubscription = _listenToGeolocationStream(track.id);
      } else {
        _clearMapSourcesAndLayers(); // Clear map if trackId is null
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
  _listenToGeolocationStream(int trackId) {
    return isarService.geolocationService.getGeolocationStream().then((stream) {
      stream.listen((e) async {
        List<GeolocationData> geoData = await isarService.geolocationService
            .getGeolocationDataByTrackId(trackId);

        // If geolocation data is available, update the map source and layer
        if (geoData.isNotEmpty) {
          _updateMapWithGeolocationData(geoData);
        }
      });
    });
  }

  // Create or update the map source with new geolocation data
  void _updateMapWithGeolocationData(List<GeolocationData> geoData) async {
    // Create the GeoJSON FeatureCollection
    final geoJsonData = jsonEncode({
      "type": "Feature",
      "properties": {},
      "geometry": {
        "type": "LineString",
        "coordinates": geoData.map((location) {
          return [location.longitude, location.latitude];
        }).toList(),
      }
    });

    // Remove the old source and layer if they exist
    await _clearMapSourcesAndLayers();

    // Create a new source with the updated GeoJSON data
    GeoJsonSource lineSource = GeoJsonSource(
      id: "lineSource",
      data: geoJsonData,
    );

    // Add the new source to the map
    await mapInstance.style.addSource(lineSource);

    // // Add a line layer to display the geolocation points on the map
    LineLayer lineLayer = LineLayer(
        id: "lineLayer",
        sourceId: "lineSource",
        lineColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.value
            : Colors.black.value,
        lineWidth: 4.0,
        lineEmissiveStrength: 1,
        lineCap: LineCap.ROUND);

    // Add the layer to the map
    await mapInstance.style.addLayer(lineLayer);

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

  // Clear the map by removing the source and layers
  Future<void> _clearMapSourcesAndLayers() async {
    try {
      // Remove existing layers and sources
      if (await mapInstance.style.styleLayerExists("lineLayer")) {
        await mapInstance.style.removeStyleLayer("lineLayer");
      }
      if (await mapInstance.style.styleSourceExists("lineSource")) {
        await mapInstance.style.removeStyleSource("lineSource");
      }
    } catch (e) {
      print("Error removing sources and layers: $e");
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
    return MapWidget(
      styleUri: MapboxStyles.STANDARD,
      onStyleLoadedListener: (styleLoadedEventData) async {
        String style =
            Theme.of(context).brightness == Brightness.dark ? "night" : "day";
        mapInstance.style
            .setStyleImportConfigProperty("basemap", "lightPreset", style);
      },
      onMapCreated: (mapInstance) {
        this.mapInstance = mapInstance;
        mapInstance.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
        mapInstance.compass.updateSettings(CompassSettings(enabled: false));
        mapInstance.attribution
            .updateSettings(AttributionSettings(marginBottom: 75));
        mapInstance.logo
            .updateSettings(LogoSettings(marginBottom: 75, marginLeft: 8));

        // Set initial camera position
        mapInstance.setCamera(CameraOptions(
          center: Point(coordinates: Position(7, 35)),
          zoom: 3.0,
          pitch: 25,
        ));
      },
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{}
        ..add(Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()))
        ..add(Factory<PanGestureRecognizer>(() => PanGestureRecognizer()))
        ..add(Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()))
        ..add(Factory<TapGestureRecognizer>(() => TapGestureRecognizer()))
        ..add(Factory<VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer())),
    );
  }
}
