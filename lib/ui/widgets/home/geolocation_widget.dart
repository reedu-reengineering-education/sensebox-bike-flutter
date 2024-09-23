import 'dart:async';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../blocs/geolocation_bloc.dart';
import '../../../secrets.dart'; // File containing the Mapbox token

class GeolocationMapWidget extends StatefulWidget {
  const GeolocationMapWidget({super.key});

  @override
  _GeolocationMapWidgetState createState() => _GeolocationMapWidgetState();
}

class _GeolocationMapWidgetState extends State<GeolocationMapWidget>
    with WidgetsBindingObserver {
  late final MapboxMap mapInstance;
  late final StreamSubscription<GeolocationData> _geolocationSubscription;

  @override
  void didChangePlatformBrightness() async {
    super.didChangePlatformBrightness();

    if (!await mapInstance.style.isStyleLoaded()) {
      return;
    }

    String style =
        Theme.of(context).brightness == Brightness.dark ? "day" : "night";

    mapInstance.style
        .setStyleImportConfigProperty("basemap", "lightPreset", style);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Get the GeolocationBloc from the context
    final geolocationBloc =
        Provider.of<GeolocationBloc>(context, listen: false);

    // Set the access token for Mapbox
    MapboxOptions.setAccessToken(mapboxAccessToken);

    // Subscribe to the geolocation stream
    _geolocationSubscription =
        geolocationBloc.geolocationStream.listen((geolocationData) {
      mapInstance.flyTo(
        CameraOptions(
          zoom: 16.0,
          pitch: 45,
          center: Point(
              coordinates: Position(
                  geolocationData.longitude, geolocationData.latitude)),
        ),
        MapAnimationOptions(
          duration: 1000,
        ),
      );
    });
  }

  @override
  void dispose() {
    _geolocationSubscription.cancel();
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
        // mapInstance.location.updateSettings(LocationComponentSettings(
        //   enabled: true,
        //   showAccuracyRing: true,
        // ));
        mapInstance.compass.updateSettings(CompassSettings(enabled: false));
        mapInstance.attribution
            .updateSettings(AttributionSettings(marginBottom: 75));
        mapInstance.logo
            .updateSettings(LogoSettings(marginBottom: 75, marginLeft: 8));

        mapInstance.setCamera(CameraOptions(
          center: Point(
            coordinates: Position(7, 35),
          ),
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
