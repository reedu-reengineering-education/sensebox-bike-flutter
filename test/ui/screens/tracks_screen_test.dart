import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
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
    when(() => mockIsarService.trackService.getAllTracks())
        .thenAnswer((_) async => []);
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
        home: ChangeNotifierProvider<TrackBloc>.value(
          value: mockTrackBloc,
          child: const TracksScreen(),
        ),
      ),
    );

    await tester.pump();
  }

  group('TracksScreen', () {
    testWidgets('displays loading indicator while tracks are loading',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpTracksScreen(
          tester,
          tracksFuture: Future.delayed(
            const Duration(seconds: 1),
            () => <TrackData>[],
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  });
}