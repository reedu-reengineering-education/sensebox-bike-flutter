import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class MockIsarService extends Mock implements IsarService {}

class MockTrackService extends Mock implements TrackService {}

class MockTrackBloc extends Mock implements TrackBloc {}

class MockRecordingBloc extends Mock implements RecordingBloc {}

void main() {
  late MockIsarService mockIsarService;
  late MockTrackService mockTrackService;
  late MockTrackBloc mockTrackBloc;
  late MockRecordingBloc mockRecordingBloc;

  setUp(() {
    mockIsarService = MockIsarService();
    mockTrackService = MockTrackService();
    mockTrackBloc = MockTrackBloc();
    mockRecordingBloc = MockRecordingBloc();

    when(() => mockIsarService.trackService).thenReturn(mockTrackService);
    when(() => mockTrackBloc.isarService).thenReturn(mockIsarService);
    when(() => mockRecordingBloc.isRecording).thenReturn(false);
    when(() => mockRecordingBloc.isRecordingNotifier)
        .thenReturn(ValueNotifier<bool>(false));
  });

  Future<void> pumpTracksScreen(WidgetTester tester, Locale locale) async {
    when(() => mockTrackService.getAllTracks())
        .thenAnswer((_) async => <TrackData>[]);
    when(() => mockTrackService.getTracksPaginated(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          skipLastTrack: any(named: 'skipLastTrack'),
        )).thenAnswer((_) async => <TrackData>[]);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
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

    await tester.pumpAndSettle();
  }

  group('TracksScreen Widget', () {
    testWidgets("is translated in English", (WidgetTester tester) async {
      await pumpTracksScreen(tester, const Locale('en'));
      expect(find.text('Your tracks'), findsOneWidget);
    });

    testWidgets("is translated in German", (WidgetTester tester) async {
      await pumpTracksScreen(tester, const Locale('de'));
      expect(find.text('Deine Tracks'), findsOneWidget);
    });

    testWidgets("is translated in Portuguese", (WidgetTester tester) async {
      await pumpTracksScreen(tester, const Locale('pt'));
      expect(find.text('Seus trajetos'), findsOneWidget);
    });
  });
}
