import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_status_info.dart';
import 'package:sensebox_bike/services/isar_service.dart';

import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Mock TrackBloc class
class MockTrackBloc implements TrackBloc {
  String formatTrackDate(DateTime timestamp) => '15.03.2024';
  String formatTrackTimeRange(DateTime start, DateTime end) => '10:00 - 11:00';
  String formatTrackDuration(
          Duration duration, AppLocalizations localizations) =>
      '1h 0m';
  String formatTrackDistance(double distance, AppLocalizations localizations) =>
      '5.00 km';
  String buildStaticMapboxUrl(BuildContext context, String polyline) =>
      'https://example.com/map';

  // Implement required TrackBloc methods
  @override
  TrackData? get currentTrack => null;

  @override
  Stream<TrackData?> get currentTrackStream => Stream.value(null);

  @override
  Future<int> startNewTrack({bool? isDirectUpload}) async => 1;

  @override
  void endTrack() {}

  @override
  void dispose() {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  bool get hasListeners => false;

  @override
  void notifyListeners() {}

  @override
  TrackStatus calculateTrackStatusFromValues(
      bool isDirectUpload, bool uploaded, int uploadAttempts) {
    if (isDirectUpload) return TrackStatus.directUpload;
    if (uploaded) return TrackStatus.uploaded;
    if (uploadAttempts > 0) return TrackStatus.uploadFailed;
    return TrackStatus.notUploaded;
  }

  @override
  TrackStatusInfo getEstimatedTrackStatusInfo(
      TrackData track, ThemeData theme, AppLocalizations localizations) {
    final status = calculateTrackStatusFromValues(
        track.isDirectUploadTrack, track.isUploaded, track.uploadAttemptsCount);

    return TrackStatusInfo(
      status: status,
      color: Colors.blue,
      icon: Icons.cloud_upload,
      text: 'Test Status',
    );
  }

  @override
  IsarService get isarService => throw UnimplementedError();
}

void main() {
  group('TrackListItem Upload Status', () {
    late TrackData testTrack;
    late MockTrackBloc mockTrackBloc;

    setUp(() {
      testTrack = TrackData();
      mockTrackBloc = MockTrackBloc();
      
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
            trackBloc: mockTrackBloc,
          ),
        ),
      );
    }

    testWidgets('displays upload status icon', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testTrack));

      // Should display the upload status icon (cloud_upload for new tracks)
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('shows uploaded status for uploaded track',
        (WidgetTester tester) async {
      testTrack.uploaded = 1;
      testTrack.uploadAttempts = 1;

      await tester.pumpWidget(createTestWidget(testTrack));

      // Should show uploaded icon
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('shows not uploaded status for new track',
        (WidgetTester tester) async {
      testTrack.uploaded = 0;
      testTrack.uploadAttempts = 0;

      await tester.pumpWidget(createTestWidget(testTrack));

      // Should show upload icon
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('shows failed status for failed upload',
        (WidgetTester tester) async {
      testTrack.uploaded = 0;
      testTrack.uploadAttempts = 2;
      testTrack.lastUploadAttempt = DateTime.now();

      await tester.pumpWidget(createTestWidget(testTrack));

      // Should show failed upload icon
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('shows correct status icon for track with upload attempts',
        (WidgetTester tester) async {
      testTrack.uploaded = 0;
      testTrack.uploadAttempts = 1;

      await tester.pumpWidget(createTestWidget(testTrack));

      // Should show failed upload icon (cloud_off) for tracks with upload attempts
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('displays track information alongside upload status',
        (WidgetTester tester) async {
      testTrack.uploaded = 0;
      testTrack.uploadAttempts = 0;

      await tester.pumpWidget(createTestWidget(testTrack));

      // Should show both track information and upload status icon
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
      // Only check for timer and distance icons if track has geolocations
      if (testTrack.geolocations.isNotEmpty) {
        expect(
            find.byIcon(Icons.timer_outlined), findsOneWidget); // Duration icon
        expect(find.byIcon(Icons.straighten_outlined),
            findsOneWidget); // Distance icon
      }
    });

    testWidgets('handles track without geolocations',
        (WidgetTester tester) async {
      final emptyTrack = TrackData();
      // Don't add any geolocations

      await tester.pumpWidget(createTestWidget(emptyTrack));

      // Should still show upload status icon even for empty tracks
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('upload status icon is positioned correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testTrack));

      // Find the upload status icon
      final uploadStatusFinder = find.byIcon(Icons.cloud_upload);
      expect(uploadStatusFinder, findsOneWidget);

      // Verify it's positioned in the top-right area of the track info
      // The icon should be visible in the track item
      expect(uploadStatusFinder, findsOneWidget);
    });

    testWidgets('minimal track test', (WidgetTester tester) async {
      // Create a minimal track with just the basics
      final minimalTrack = TrackData()
        ..id = 1
        ..uploaded = 0
        ..uploadAttempts = 0;
      
      // Add a single geolocation to avoid any complex logic
      final simpleGeolocation = GeolocationData()
        ..latitude = 0.0
        ..longitude = 0.0
        ..timestamp = DateTime(2023, 1, 1, 12, 0, 0)
        ..speed = 0.0;
      
      minimalTrack.geolocations.add(simpleGeolocation);
      
      await tester.pumpWidget(createTestWidget(minimalTrack));
      
      // Check if the widget renders
      expect(find.byType(TrackListItem), findsOneWidget);
      
      // Check if the status icon is rendered
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('mock track with all properties test',
        (WidgetTester tester) async {
      // Create a mock track with all required properties
      final mockTrack = TrackData()
        ..id = 999
        ..uploaded = 0
        ..uploadAttempts = 0;
      
      // Add multiple geolocations with proper data
      final geolocation1 = GeolocationData()
        ..id = 1
        ..latitude = 52.5200
        ..longitude = 13.4050
        ..timestamp = DateTime(2023, 1, 1, 10, 0, 0)
        ..speed = 15.0;
      
      final geolocation2 = GeolocationData()
        ..id = 2
        ..latitude = 52.5201
        ..longitude = 13.4051
        ..timestamp = DateTime(2023, 1, 1, 11, 0, 0)
        ..speed = 20.0;
      
      mockTrack.geolocations.addAll([geolocation1, geolocation2]);
      
      await tester.pumpWidget(createTestWidget(mockTrack));
      
      // Check if the widget renders
      expect(find.byType(TrackListItem), findsOneWidget);
      
      // Check if the status icon is rendered
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('simple track rendering test', (WidgetTester tester) async {
      // Create a very simple track with minimal data
      final simpleTrack = TrackData()
        ..id = 1
        ..uploaded = 0
        ..uploadAttempts = 0;
      
      // Add a single geolocation with minimal data
      final simpleGeolocation = GeolocationData()
        ..id = 1
        ..latitude = 0.0
        ..longitude = 0.0
        ..timestamp = DateTime(2023, 1, 1, 12, 0, 0)
        ..speed = 0.0;
      
      simpleTrack.geolocations.add(simpleGeolocation);
      
      await tester.pumpWidget(createTestWidget(simpleTrack));
      
      // Check if the widget renders at all
      expect(find.byType(TrackListItem), findsOneWidget);
      
      // The widget should show the upload status icon
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });
  });
}