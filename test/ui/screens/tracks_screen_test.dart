import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/no_tracks_message.dart';
import '../../mocks.dart';

class MockIsarService extends Mock implements IsarService {}

class MockTrackService extends Mock implements TrackService {}

class MockTrackBloc extends TrackBloc {
  MockTrackBloc(super.isarService);
}

void main() {
  late MockIsarService mockIsarService;
  late MockTrackService mockTrackService;
  late MockTrackBloc mockTrackBloc;
  late MockRecordingBloc mockRecordingBloc;

  setUp(() {
    mockIsarService = MockIsarService();
    mockTrackService = MockTrackService();
    mockTrackBloc = MockTrackBloc(mockIsarService);
    mockRecordingBloc = MockRecordingBloc();

    when(() => mockIsarService.trackService).thenReturn(mockTrackService);
  });

  Future<void> pumpTracksScreen(
    WidgetTester tester, {
    required List<TrackData> tracks,
  }) async {
    when(() => mockTrackService.getAllTracks()).thenAnswer((_) async => tracks);
    when(() => mockTrackService.getTracksPaginated(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          skipLastTrack: any(named: 'skipLastTrack'),
        )).thenAnswer((_) async => tracks);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<TrackBloc>.value(
              value: mockTrackBloc,
            ),
            ChangeNotifierProvider<RecordingBloc>.value(
              value: mockRecordingBloc,
            ),
          ],
          child: const TracksScreen(),
        ),
      ),
    );

    // Allow the initial loading to complete
    await tester.pumpAndSettle();
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
