import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../mocks.dart';

void main() {
  group('TracksScreen Widget', () {
    late MockIsarService mockIsarService;
    late MockTrackBloc mockTrackBloc;

    setUp(() {
      mockIsarService = MockIsarService();
      mockTrackBloc = MockTrackBloc();
      when(() => mockTrackBloc.isarService).thenReturn(mockIsarService);
      when(() => mockIsarService.trackService.getAllTracks())
          .thenAnswer((_) async => []);
    });

    Future<void> pumpTracksScreen(WidgetTester tester, Locale locale) async {
      final tracksFuture = Future.delayed(
        const Duration(seconds: 1),
        () => <TrackData>[],
      );
      when(() => mockIsarService.trackService.getAllTracks())
          .thenAnswer((_) => tracksFuture);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: ChangeNotifierProvider<TrackBloc>.value(
            value: mockTrackBloc,
            child: const TracksScreen(),
          ),
        ),
      );
    }

    testWidgets("is translated in English", (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpTracksScreen(tester, const Locale('en'));

        // Simulate the passage of time
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Tracks'), findsOneWidget);
      });
    });

    testWidgets("is translated in German", (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpTracksScreen(tester, const Locale('de'));

        // Simulate the passage of time
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Tracks'), findsOneWidget);
      });
    });

    testWidgets("is translated in Portuguese", (WidgetTester tester) async {
      await tester.runAsync(() async {
        await pumpTracksScreen(tester, const Locale('pt'));

        // Simulate the passage of time
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Trajetos'), findsOneWidget);
      });
    });
  });
}
