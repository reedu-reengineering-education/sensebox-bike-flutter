import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../mocks.dart';

void main() {
  late MockIsarService mockIsarService;
  late MockTrackBloc mockTrackBloc;

  setUp(() {
    mockIsarService = MockIsarService();
    mockTrackBloc = MockTrackBloc();
    when(() => mockTrackBloc.isarService).thenReturn(mockIsarService);
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
    // TBD: Add more tests for the TracksScreen widget
  });
}