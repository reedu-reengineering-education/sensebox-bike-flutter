import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/utils/track_collection_mode_display.dart';

import '../mocks.dart';

void main() {
  group('collectionModeDisplay', () {
    late AppLocalizations localizations;

    setUpAll(() async {
      localizations = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('returns null for legacy track with null dataCollectionMode', () {
      final track = TestTrackBuilder.createTrack();

      expect(collectionModeDisplay(track, localizations), isNull);
    });

    test('returns null for gpsDriven mode', () {
      final track = TestTrackBuilder.createTrack(
        dataCollectionMode: DataCollectionMode.gpsDriven.toJson(),
      );

      expect(collectionModeDisplay(track, localizations), isNull);
    });

    test('returns periodic display with interval from track', () {
      final track = TestTrackBuilder.createTrack(
        dataCollectionMode: DataCollectionMode.periodic.toJson(),
        collectionIntervalSeconds: 30,
      );

      final display = collectionModeDisplay(track, localizations);

      expect(display, isNotNull);
      expect(display!.icon, Icons.schedule);
      expect(display.text, localizations.trackCollectionModePeriodic(30));
    });

    test('uses default interval when periodic track has null interval', () {
      final track = TestTrackBuilder.createTrack(
        dataCollectionMode: DataCollectionMode.periodic.toJson(),
      );

      final display = collectionModeDisplay(track, localizations);

      expect(display, isNotNull);
      expect(
        display!.text,
        localizations.trackCollectionModePeriodic(
          defaultCollectionIntervalSeconds,
        ),
      );
    });

    test('returns onTap display', () {
      final track = TestTrackBuilder.createTrack(
        dataCollectionMode: DataCollectionMode.onTap.toJson(),
      );

      final display = collectionModeDisplay(track, localizations);

      expect(display, isNotNull);
      expect(display!.icon, Icons.add_location_alt);
      expect(display.text, localizations.trackCollectionModeOnTap);
    });
  });
}
