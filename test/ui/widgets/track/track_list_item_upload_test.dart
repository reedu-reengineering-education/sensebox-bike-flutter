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

  //   testWidgets('displays upload status icon', (WidgetTester tester) async {
  //     // Debug: print track properties
  //     print('Test track - uploaded: ${testTrack.uploaded}, uploadAttempts: ${testTrack.uploadAttempts}');
  //     print('Test track has ${testTrack.geolocations.length} geolocations');

  //     // Test with error handling
  //     try {
  //       await tester.pumpWidget(createTestWidget(testTrack));

  //       // Debug: print what widgets are found
  //       print('Found widgets: ${find.byType(Icon).evaluate().length}');
  //       print('Found cloud_upload icons: ${find.byIcon(Icons.cloud_upload).evaluate().length}');

  //       // Should display the upload status icon (cloud_upload for new tracks)
  //       expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  //     } catch (e, stackTrace) {
  //       print('Error during test: $e');
  //       print('Stack trace: $stackTrace');
  //       rethrow;
  //     }
  //   });

  //   testWidgets('basic widget rendering test', (WidgetTester tester) async {
  //     // Simple test to see if the widget renders at all
  //     await tester.pumpWidget(createTestWidget(testTrack));

  //     // Check if the widget is rendered
  //     expect(find.byType(TrackListItem), findsOneWidget);

  //     // Check if we can find any icons at all
  //     final iconCount = find.byType(Icon).evaluate().length;
  //     print('Total icons found: $iconCount');

  //     // Check if we can find the track content
  //     expect(find.byType(Row), findsWidgets);
  //   });

  //   testWidgets('shows uploaded status for uploaded track', (WidgetTester tester) async {
  //     testTrack.uploaded = true;
  //     testTrack.uploadAttempts = 1;

  //     print('Test track - uploaded: ${testTrack.uploaded}, uploadAttempts: ${testTrack.uploadAttempts}');

  //     await tester.pumpWidget(createTestWidget(testTrack));

  //     // Should show uploaded icon
  //     expect(find.byIcon(Icons.cloud_done), findsOneWidget);
  //   });

  //   testWidgets('shows not uploaded status for new track', (WidgetTester tester) async {
  //     testTrack.uploaded = false;
  //     testTrack.uploadAttempts = 0;

  //     print('Test track - uploaded: ${testTrack.uploaded}, uploadAttempts: ${testTrack.uploadAttempts}');

  //     await tester.pumpWidget(createTestWidget(testTrack));

  //     // Should show upload icon
  //     expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  //   });

  //   testWidgets('shows failed status for failed upload', (WidgetTester tester) async {
  //     testTrack.uploaded = false;
  //     testTrack.uploadAttempts = 2;
  //     testTrack.lastUploadAttempt = DateTime.now();

  //     print('Test track - uploaded: ${testTrack.uploaded}, uploadAttempts: ${testTrack.uploadAttempts}');

  //     await tester.pumpWidget(createTestWidget(testTrack));

  //     // Should show failed upload icon
  //     expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  //   });

  //   testWidgets('shows correct status icon for track with upload attempts', (WidgetTester tester) async {
  //     testTrack.uploaded = false;
  //     testTrack.uploadAttempts = 1;

  //     print('Test track - uploaded: ${testTrack.uploaded}, uploadAttempts: ${testTrack.uploadAttempts}');

  //     await tester.pumpWidget(createTestWidget(testTrack));

  //     // Should show failed upload icon (cloud_off) for tracks with upload attempts
  //     expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  //   });

  //   testWidgets('displays track information alongside upload status', (WidgetTester tester) async {
  //     testTrack.uploaded = false;
  //     testTrack.uploadAttempts = 0;

  //     await tester.pumpWidget(createTestWidget(testTrack));

  //     // Should show both track information and upload status icon
  //     expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  //     // Only check for timer and distance icons if track has geolocations
  //     if (testTrack.geolocations.isNotEmpty) {
  //       expect(find.byIcon(Icons.timer_outlined), findsOneWidget); // Duration icon
  //       expect(find.byIcon(Icons.straighten_outlined), findsOneWidget); // Distance icon
  //     }
  //   });

  //   testWidgets('handles track without geolocations', (WidgetTester tester) async {
  //     final emptyTrack = TrackData();
  //     // Don't add any geolocations

  //     await tester.pumpWidget(createTestWidget(emptyTrack));

  //     // Should still show upload status icon even for empty tracks
  //     expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  //   });

  //   testWidgets('upload status icon is positioned correctly', (WidgetTester tester) async {
  //     await tester.pumpWidget(createTestWidget(testTrack));

  //     // Find the upload status icon
  //     final uploadStatusFinder = find.byIcon(Icons.cloud_upload);
  //     expect(uploadStatusFinder, findsOneWidget);

  //     // Verify it's positioned in the top-right area of the track info
  //     // The icon should be visible in the track item
  //     expect(uploadStatusFinder, findsOneWidget);
  //   });

  //   testWidgets('minimal track test', (WidgetTester tester) async {
  //     // Create a minimal track with just the basics
  //     final minimalTrack = TrackData()
  //       ..id = 1
  //       ..uploaded = false
  //       ..uploadAttempts = 0;
      
  //     // Add a single geolocation to avoid any complex logic
  //     final simpleGeolocation = GeolocationData()
  //       ..latitude = 0.0
  //       ..longitude = 0.0
  //       ..timestamp = DateTime(2023, 1, 1, 12, 0, 0)
  //       ..speed = 0.0;
      
  //     minimalTrack.geolocations.add(simpleGeolocation);
      
  //     print('Minimal track - id: ${minimalTrack.id}, uploaded: ${minimalTrack.uploaded}, geolocations: ${minimalTrack.geolocations.length}');
      
  //     await tester.pumpWidget(createTestWidget(minimalTrack));
      
  //     // Check if the widget renders
  //     expect(find.byType(TrackListItem), findsOneWidget);
      
  //     // Check if we can find any icons
  //     final iconCount = find.byType(Icon).evaluate().length;
  //     print('Total icons found in minimal test: $iconCount');
      
  //     // Check if the status icon is rendered
  //     expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  //   });

  //   testWidgets('mock track with all properties test', (WidgetTester tester) async {
  //     // Create a mock track with all required properties
  //     final mockTrack = TrackData()
  //       ..id = 999
  //       ..uploaded = false
  //       ..uploadAttempts = 0;
      
  //     // Add multiple geolocations with proper data
  //     final geolocation1 = GeolocationData()
  //       ..id = 1
  //       ..latitude = 52.5200
  //       ..longitude = 13.4050
  //       ..timestamp = DateTime(2023, 1, 1, 10, 0, 0)
  //       ..speed = 15.0;
      
  //     final geolocation2 = GeolocationData()
  //       ..id = 2
  //       ..latitude = 52.5201
  //       ..longitude = 13.4051
  //       ..timestamp = DateTime(2023, 1, 1, 11, 0, 0)
  //       ..speed = 20.0;
      
  //     mockTrack.geolocations.addAll([geolocation1, geolocation2]);
      
  //     print('Mock track - id: ${mockTrack.id}, uploaded: ${mockTrack.uploaded}, geolocations: ${mockTrack.geolocations.length}');
  //     print('Geolocation 1: lat=${geolocation1.latitude}, lon=${geolocation1.longitude}, time=${geolocation1.timestamp}');
  //     print('Geolocation 2: lat=${geolocation2.latitude}, lon=${geolocation2.longitude}, time=${geolocation2.timestamp}');
      
  //     await tester.pumpWidget(createTestWidget(mockTrack));
      
  //     // Check if the widget renders
  //     expect(find.byType(TrackListItem), findsOneWidget);
      
  //     // Check if we can find any icons
  //     final iconCount = find.byType(Icon).evaluate().length;
  //     print('Total icons found in mock test: $iconCount');
      
  //     // Check if the status icon is rendered
  //     expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  //   });

  //   testWidgets('simple track rendering test', (WidgetTester tester) async {
  //     // Create a very simple track with minimal data
  //     final simpleTrack = TrackData()
  //       ..id = 1
  //       ..uploaded = false
  //       ..uploadAttempts = 0;
      
  //     // Add a single geolocation with minimal data
  //     final simpleGeolocation = GeolocationData()
  //       ..id = 1
  //       ..latitude = 0.0
  //       ..longitude = 0.0
  //       ..timestamp = DateTime(2023, 1, 1, 12, 0, 0)
  //       ..speed = 0.0;
      
  //     simpleTrack.geolocations.add(simpleGeolocation);
      
  //     print('Simple track - id: ${simpleTrack.id}, uploaded: ${simpleTrack.uploaded}, geolocations: ${simpleTrack.geolocations.length}');
      
  //     await tester.pumpWidget(createTestWidget(simpleTrack));
      
  //     // Check if the widget renders at all
  //     expect(find.byType(TrackListItem), findsOneWidget);
      
  //     // Check if we can find any icons
  //     final iconCount = find.byType(Icon).evaluate().length;
  //     print('Total icons found in simple test: $iconCount');
      
  //     // The widget should show the upload status icon
  //     expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  //   });
  // });

}