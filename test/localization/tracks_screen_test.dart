import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

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

  Future<void> pumpTracksScreen(WidgetTester tester, Locale locale) async {
    when(() => mockTrackService.getAllTracks())
        .thenAnswer((_) async => <TrackData>[]);

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

    await tester
        .pumpAndSettle(); // Ensure all asynchronous operations are completed
  }

  group('TracksScreen Widget', () {
    testWidgets("is translated in English", (WidgetTester tester) async {
      await pumpTracksScreen(tester, const Locale('en'));
      expect(find.text('Tracks'), findsOneWidget);
    });

    testWidgets("is translated in German", (WidgetTester tester) async {
      await pumpTracksScreen(tester, const Locale('de'));
      expect(find.text('Tracks'), findsOneWidget);
    });

    testWidgets("is translated in Portuguese", (WidgetTester tester) async {
      await pumpTracksScreen(tester, const Locale('pt'));
      expect(find.text('Trajetos'), findsOneWidget);
    });
  });
}
