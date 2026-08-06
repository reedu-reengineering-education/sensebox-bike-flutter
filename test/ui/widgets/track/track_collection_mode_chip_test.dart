import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/ui/widgets/track/track_collection_mode_chip.dart';

import '../../../mocks.dart';

void main() {
  group('TrackCollectionModeChip', () {
    Widget buildWidget(TrackData track) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TrackCollectionModeChip(track: track),
        ),
      );
    }

    testWidgets('shows periodic chip text', (tester) async {
      final track = TestTrackBuilder.createTrack(
        dataCollectionMode: DataCollectionMode.periodic.toJson(),
        collectionIntervalSeconds: 60,
      );

      await tester.pumpWidget(buildWidget(track));
      await tester.pumpAndSettle();

      expect(find.text('Every 60 s'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('shows onTap chip text', (tester) async {
      final track = TestTrackBuilder.createTrack(
        dataCollectionMode: DataCollectionMode.onTap.toJson(),
      );

      await tester.pumpWidget(buildWidget(track));
      await tester.pumpAndSettle();

      expect(find.text('Manual sampling'), findsOneWidget);
      expect(find.byIcon(Icons.add_location_alt), findsOneWidget);
    });

    testWidgets('renders nothing for gpsDriven track', (tester) async {
      final track = TestTrackBuilder.createTrack(
        dataCollectionMode: DataCollectionMode.gpsDriven.toJson(),
      );

      await tester.pumpWidget(buildWidget(track));
      await tester.pumpAndSettle();

      expect(find.byType(TrackCollectionModeChip), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsNothing);
      expect(find.byIcon(Icons.add_location_alt), findsNothing);
      expect(find.text('Manual sampling'), findsNothing);
      expect(find.textContaining('Every'), findsNothing);
    });
  });
}
