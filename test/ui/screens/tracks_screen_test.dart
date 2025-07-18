import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';
import 'package:sensebox_bike/ui/widgets/common/no_tracks_message.dart';

class MockIsarService extends Mock implements IsarService {}

class MockTrackService extends Mock implements TrackService {}

class MockTrackBloc extends Mock implements TrackBloc {}

void main() {
  late MockIsarService mockIsarService;
  late MockTrackService mockTrackService;
  late MockTrackBloc mockTrackBloc;

  setUp(() {
    mockIsarService = MockIsarService();
    mockTrackService = MockTrackService();
    mockTrackBloc = MockTrackBloc();

    when(() => mockIsarService.trackService).thenReturn(mockTrackService);
    when(() => mockTrackBloc.isarService).thenReturn(mockIsarService);
  });

  Future<void> pumpTracksScreen(
    WidgetTester tester, {
    required List<TrackData> tracks,
  }) async {
    when(() => mockIsarService.getTracksPaginated(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => tracks);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TrackBloc>.value(
          value: mockTrackBloc,
          child: const TracksScreen(),
        ),
      ),
    );

    // Allow the initial loading to complete
    await tester.pump();
  }

  group('TracksScreen', () {
    testWidgets('displays no tracks message when no tracks are available',
        (WidgetTester tester) async {
      await pumpTracksScreen(tester, tracks: []);

      // Wait for the loading to complete
      await tester.pump();

      // Should show the NoTracksMessage widget
      expect(find.byType(NoTracksMessage), findsOneWidget);
      expect(find.text('No tracks available'), findsOneWidget);
    });

    // TBD: fix tests for loading tracks
    // testWidgets('displays loading indicator while tracks are loading',
    //     (WidgetTester tester) async {
    //   await pumpTracksScreen(
    //     tester,
    //     tracksFuture: Future.delayed(
    //       const Duration(seconds: 1),
    //       () => <TrackData>[],
    //     ),
    //   );

    //   expect(find.byType(CircularProgressIndicator), findsOneWidget);

    //   await tester.pump(const Duration(seconds: 1));

    //   expect(find.byType(TrackListItem), findsNothing);
    // });

    // Add more tests for pagination and other behaviors
  });
}
