import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';

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
    required Future<List<TrackData>> tracksFuture,
  }) async {
    when(() => mockTrackService.getAllTracks()).thenAnswer((_) => tracksFuture);

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

    await tester.pump();
  }

  group('TracksScreen', () {
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