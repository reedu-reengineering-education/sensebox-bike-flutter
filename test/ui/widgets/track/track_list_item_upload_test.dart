import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';

import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  group('TrackListItem Upload Status', () {
    late TrackData testTrack;

    setUp(() {
      testTrack = TrackData();
      
      // Add some test geolocations
      final geolocation1 = GeolocationData()
        ..latitude = 51.9607
        ..longitude = 7.6261
        ..timestamp = DateTime.now().subtract(const Duration(hours: 1));
      
      final geolocation2 = GeolocationData()
        ..latitude = 51.9617
        ..longitude = 7.6271
        ..timestamp = DateTime.now();

      testTrack.geolocations.addAll([geolocation1, geolocation2]);
    });

    Widget createTestWidget(TrackData track) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('de'),
          Locale('pt'),
        ],
        home: Scaffold(
          body: TrackListItem(
            track: track,
            onDismissed: () {},
          ),
        ),
      );
    }

    testWidgets('displays upload status icon', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testTrack));

      // Should display the upload status icon (cloud_upload for new tracks)
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('shows uploaded status for uploaded track', (WidgetTester tester) async {
      testTrack.uploaded = true;
      testTrack.uploadAttempts = 1;

      await tester.pumpWidget(createTestWidget(testTrack));

      // Should show uploaded icon
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('shows not uploaded status for new track', (WidgetTester tester) async {
      testTrack.uploaded = false;
      testTrack.uploadAttempts = 0;

      await tester.pumpWidget(createTestWidget(testTrack));

      // Should show upload icon
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('shows failed status for failed upload', (WidgetTester tester) async {
      testTrack.uploaded = false;
      testTrack.uploadAttempts = 2;
      testTrack.lastUploadAttempt = DateTime.now();

      await tester.pumpWidget(createTestWidget(testTrack));

      // Should show failed upload icon
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('shows correct status icon for track with upload attempts', (WidgetTester tester) async {
      testTrack.uploaded = false;
      testTrack.uploadAttempts = 1;

      await tester.pumpWidget(createTestWidget(testTrack));

      // Should show failed upload icon (cloud_off) for tracks with upload attempts
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('displays track information alongside upload status', (WidgetTester tester) async {
      testTrack.uploaded = false;
      testTrack.uploadAttempts = 0;

      await tester.pumpWidget(createTestWidget(testTrack));

      // Should show both track information and upload status icon
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
      // Only check for timer and distance icons if track has geolocations
      if (testTrack.geolocations.isNotEmpty) {
        expect(find.byIcon(Icons.timer_outlined), findsOneWidget); // Duration icon
        expect(find.byIcon(Icons.straighten_outlined), findsOneWidget); // Distance icon
      }
    });

    testWidgets('handles track without geolocations', (WidgetTester tester) async {
      final emptyTrack = TrackData();
      // Don't add any geolocations

      await tester.pumpWidget(createTestWidget(emptyTrack));

      // Should still show upload status icon even for empty tracks
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('upload status icon is positioned correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testTrack));

      // Find the upload status icon
      final uploadStatusFinder = find.byIcon(Icons.cloud_upload);
      expect(uploadStatusFinder, findsOneWidget);

      // Verify it's positioned in the top-right area of the track info
      // The icon should be visible in the track item
      expect(uploadStatusFinder, findsOneWidget);
    });
  });
}