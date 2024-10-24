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

  final isarService = IsarService();

  @override
  void initState() {
    super.initState();
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
  StreamSubscription _listenToGeolocationStream(int trackId) {
    // Access the geolocation stream from the service
    return isarService.geolocationService
        .getGeolocationStream()
        .asStream()
        .listen((event) async {
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
