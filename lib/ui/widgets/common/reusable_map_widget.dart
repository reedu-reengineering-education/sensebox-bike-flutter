import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../secrets.dart'; // File containing the Mapbox token

class ReusableMapWidget extends StatefulWidget {
  final CameraOptions? initialCameraOptions;
  final MapCreatedCallback? onMapCreated;
  final bool? scaleBarEnabled;
  final bool? compassEnabled;
  final EdgeInsets? logoMargins;
  final EdgeInsets? attributionMargins;
  final Function(MapboxMap)? onStyleLoadedCallback;

  const ReusableMapWidget({
    super.key,
    this.initialCameraOptions,
    this.onMapCreated,
    this.scaleBarEnabled = false,
    this.compassEnabled = false,
    this.logoMargins = const EdgeInsets.only(bottom: 75, left: 8),
    this.attributionMargins = const EdgeInsets.only(bottom: 75),
    this.onStyleLoadedCallback,
  });

  @override
  _ReusableMapWidgetState createState() => _ReusableMapWidgetState();
}

class _ReusableMapWidgetState extends State<ReusableMapWidget>
    with WidgetsBindingObserver {
  late MapboxMap mapInstance;

  @override
  void initState() {
    super.initState();

    // Add observer to listen for brightness changes
    WidgetsBinding.instance.addObserver(this);

    // Set the Mapbox access token globally
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();

    // Adjust map theme based on app's brightness (dark/light)
    String style = MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? "day"
        : "night";
    mapInstance.style
        .setStyleImportConfigProperty("basemap", "lightPreset", style);
  }

  @override
  void dispose() {
    // Remove observer when widget is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      styleUri: 'mapbox://styles/felixaetem/cm20uojq2004201o132dw50nl',
      onStyleLoadedListener: (styleLoadedEventData) {
        // Adjust map theme based on app's brightness (dark/light)
        String style =
            Theme.of(context).brightness == Brightness.dark ? "night" : "day";
        mapInstance.style
            .setStyleImportConfigProperty("basemap", "lightPreset", style);

        if (widget.onStyleLoadedCallback != null) {
          widget.onStyleLoadedCallback!(mapInstance);
        }
      },
      onMapCreated: (mapInstance) {
        this.mapInstance = mapInstance;

        // Apply passed or default camera options
        if (widget.initialCameraOptions != null) {
          mapInstance.setCamera(widget.initialCameraOptions!);
        }

        // Disable scale bar and compass by default or as specified
        mapInstance.scaleBar
            .updateSettings(ScaleBarSettings(enabled: widget.scaleBarEnabled!));
        mapInstance.compass
            .updateSettings(CompassSettings(enabled: widget.compassEnabled!));

        // Update logo and attribution margins
        mapInstance.logo.updateSettings(LogoSettings(
          marginBottom: widget.logoMargins?.bottom ?? 0,
          marginLeft: widget.logoMargins?.left ?? 0,
        ));
        mapInstance.attribution.updateSettings(AttributionSettings(
          marginBottom: widget.attributionMargins?.bottom ?? 0,
        ));

        if (widget.onMapCreated != null) {
          widget.onMapCreated!(mapInstance);
        }
      },
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
        Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
        Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
        Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
        Factory<VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer()),
      },
    );
  }
}
