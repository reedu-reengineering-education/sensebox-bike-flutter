import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mapbox_maps_flutter_draw/mapbox_maps_flutter_draw.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class ExclusionZonesScreen extends StatefulWidget {
  const ExclusionZonesScreen({super.key});

  @override
  State<ExclusionZonesScreen> createState() => _ExclusionZonesScreenState();
}

class _ExclusionZonesScreenState extends State<ExclusionZonesScreen> {
  @override
  Widget build(BuildContext context) {
    final mapboxDrawController = Provider.of<MapboxDrawController>(context);
    final settingsBloc = Provider.of<SettingsBloc>(context);
    final geolocationBloc = Provider.of<GeolocationBloc>(context);

    void onMapCreated(MapboxMap controller) async {
      await mapboxDrawController.initialize(
        controller,
        onChange: (event) {
          final newPolygons = mapboxDrawController.getAllPolygons();
          final newPolygonsStrings =
              newPolygons.map((e) => jsonEncode(e.toJson())).toList();
          settingsBloc.setPrivacyZones(newPolygonsStrings);
        },
      );

      final existingPolygons = settingsBloc.privacyZones
          .map((e) => Polygon.fromJson(jsonDecode(e)))
          .toList();
      await mapboxDrawController.addPolygons(existingPolygons);

      controller.location.updateSettings(LocationComponentSettings(
        enabled: true,
        showAccuracyRing: true,
      ));
      await Future.delayed(const Duration(milliseconds: 20));
      final currentPosition = await geolocationBloc.getCurrentLocation();
      await controller.flyTo(
          CameraOptions(
            center: Point(
                coordinates: Position(
                    currentPosition.longitude, currentPosition.latitude)),
            zoom: 16.0,
            pitch: 0,
          ),
          MapAnimationOptions(duration: 1000));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.generalPrivacyZones),
      ),
      body: Stack(
        children: [
          ReusableMapWidget(
            onMapCreated: onMapCreated,
            logoMargins: const EdgeInsets.all(8),
            attributionMargins: const EdgeInsets.all(8),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Column(
              children: [
                IconButton.filled(
                  icon: const Icon(Icons.undo),
                  onPressed: mapboxDrawController.editingMode ==
                          EditingMode.DRAW_POLYGON
                      ? () => mapboxDrawController.undoLastAction()
                      : null,
                ),
                IconButton.filled(
                  icon: mapboxDrawController.editingMode ==
                          EditingMode.DRAW_POLYGON
                      ? const Icon(Icons.check)
                      : const Icon(Icons.crop_square_outlined),
                  onPressed: () {
                    if (mapboxDrawController.editingMode == EditingMode.NONE) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            AppLocalizations.of(context)!.privacyZonesStart),
                      ));
                    }
                    mapboxDrawController
                        .toggleEditing(EditingMode.DRAW_POLYGON);
                  },
                ),
                IconButton.filled(
                    icon: mapboxDrawController.editingMode == EditingMode.DELETE
                        ? const Icon(Icons.check)
                        : const Icon(Icons.delete),
                    onPressed: () {
                      if (mapboxDrawController.editingMode ==
                          EditingMode.NONE) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              AppLocalizations.of(context)!.privacyZonesDelete),
                        ));
                      }
                      mapboxDrawController.toggleDeleteMode();
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
