import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/track_data.dart';

class TrackCollectionModeDisplay {
  final IconData icon;
  final String text;

  const TrackCollectionModeDisplay({
    required this.icon,
    required this.text,
  });
}

String dataCollectionModeSettingsLabel(
  DataCollectionMode mode,
  AppLocalizations localizations,
) {
  switch (mode) {
    case DataCollectionMode.gpsDriven:
      return localizations.settingsDataCollectionModeGpsDriven;
    case DataCollectionMode.periodic:
      return localizations.settingsDataCollectionModePeriodic;
    case DataCollectionMode.onTap:
      return localizations.settingsDataCollectionModeOnTap;
  }
}

TrackCollectionModeDisplay? collectionModeDisplay(
  TrackData track,
  AppLocalizations localizations,
) {
  final mode = DataCollectionMode.fromJson(track.dataCollectionMode);
  if (mode == DataCollectionMode.gpsDriven) {
    return null;
  }

  switch (mode) {
    case DataCollectionMode.periodic:
      final seconds =
          track.collectionIntervalSeconds ?? defaultCollectionIntervalSeconds;
      return TrackCollectionModeDisplay(
        icon: Icons.schedule,
        text: localizations.trackCollectionModePeriodic(seconds),
      );
    case DataCollectionMode.onTap:
      return TrackCollectionModeDisplay(
        icon: Icons.add_location_alt,
        text: localizations.trackCollectionModeOnTap,
      );
    case DataCollectionMode.gpsDriven:
      return null;
  }
}
