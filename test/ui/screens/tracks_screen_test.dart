import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MockIsarService extends Mock implements IsarService {}

void main() {
  late MockIsarService mockIsarService;

  setUp(() {
    mockIsarService = MockIsarService();
  });

  Future<void> pumpTracksScreen(
    WidgetTester tester, {
    required Future<List<TrackData>> tracksFuture,
  }) async {
    when(() => mockIsarService.trackService.getAllTracks())
        .thenAnswer((_) => tracksFuture);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TracksScreen(),
      ),
    );

    // Allow the widget tree to settle
    await tester.pump();
  }

  group('TracksScreen', () {
    testWidgets('displays loading indicator while tracks are loading',
        (WidgetTester tester) async {
      await pumpTracksScreen(
        tester,
        tracksFuture: Future.delayed(
          const Duration(seconds: 1),
          () => <TrackData>[], // Return an empty list after the delay
        ),
      );

      // Wait for the Future.delayed to complete
      await tester.pump(const Duration(seconds: 1));

      // Verify that the loading indicator is displayed
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error message when tracks loading fails',
        (WidgetTester tester) async {
      await pumpTracksScreen(
        tester,
        tracksFuture: Future.error('Failed to load tracks'),
      );

      // Allow the widget tree to settle
      await tester.pumpAndSettle();

      // Verify that the error message is displayed
      expect(find.textContaining('Failed to load tracks'), findsOneWidget);
    });

    testWidgets('displays empty state when no tracks are available',
        (WidgetTester tester) async {
      await pumpTracksScreen(
        tester,
        tracksFuture: Future.value([]),
      );

      // Allow the widget tree to settle
      await tester.pumpAndSettle();

      // Verify that the empty state message is displayed
      expect(find.textContaining('No tracks available'), findsOneWidget);
    });

    // testWidgets('displays list of tracks when data is available',
    //     (WidgetTester tester) async {
    //   final mockTracks = [
    //     TrackData(
    //       id: '1',
    //       name: 'Track 1',
    //       duration: const Duration(minutes: 10),
    //       distance: 5.0,
    //       geolocations: [/* mock geolocation data */],
    //     ),
    //     TrackData(
    //       id: '2',
    //       name: 'Track 2',
    //       duration: const Duration(minutes: 20),
    //       distance: 10.0,
    //       geolocations: [/* mock geolocation data */],
    //     ),
    //   ];

    //   await pumpTracksScreen(
    //     tester,
    //     tracksFuture: Future.value(mockTracks),
    //   );

    //   // Allow the widget tree to settle
    //   await tester.pumpAndSettle();

    //   // Verify that the tracks are displayed
    //   expect(find.text('Track 1'), findsOneWidget);
    //   expect(find.text('Track 2'), findsOneWidget);
    // });

    // testWidgets('refreshes tracks when pull-to-refresh is triggered',
    //     (WidgetTester tester) async {
    //   final initialTracks = [
    //     TrackData(
    //       id: '1',
    //       name: 'Track 1',
    //       duration: const Duration(minutes: 10),
    //       distance: 5.0,
    //       geolocations: [/* mock geolocation data */],
    //     ),
    //   ];

    //   final refreshedTracks = [
    //     TrackData(
    //       id: '2',
    //       name: 'Track 2',
    //       duration: const Duration(minutes: 20),
    //       distance: 10.0,
    //       geolocations: [/* mock geolocation data */],
    //     ),
    //   ];

    //   when(() => mockIsarService.trackService.getAllTracks())
    //       .thenAnswer((_) => Future.value(initialTracks));

    //   await tester.pumpWidget(
    //     MaterialApp(
    //       localizationsDelegates: AppLocalizations.localizationsDelegates,
    //       supportedLocales: AppLocalizations.supportedLocales,
    //       home: TracksScreen(),
    //     ),
    //   );

    //   // Allow the widget tree to settle
    //   await tester.pumpAndSettle();

    //   // Verify initial tracks are displayed
    //   expect(find.text('Track 1'), findsOneWidget);
    //   expect(find.text('Track 2'), findsNothing);

    //   // Simulate pull-to-refresh
    //   when(() => mockIsarService.trackService.getAllTracks())
    //       .thenAnswer((_) => Future.value(refreshedTracks));

    //   await tester.drag(find.byType(RefreshIndicator), const Offset(0, 200));
    //   await tester.pumpAndSettle();

    //   // Verify refreshed tracks are displayed
    //   expect(find.text('Track 1'), findsNothing);
    //   expect(find.text('Track 2'), findsOneWidget);
    // });
  
  });
}