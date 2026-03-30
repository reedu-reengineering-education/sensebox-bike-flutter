import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class MockIsarService extends Mock implements IsarService {}

class MockTrackService extends Mock implements TrackService {}

class MockTrackBloc extends Mock implements TrackBloc {}

class MockRecordingBloc extends Mock implements RecordingBloc {}

class MockOpenSenseMapBloc extends Mock implements OpenSenseMapBloc {}

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}

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
    when(() => mockTrackBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockTrackBloc.state)
        .thenReturn(const TrackState(currentTrack: null));

    when(() => mockRecordingBloc.isRecording).thenReturn(false);
    when(() => mockRecordingBloc.isRecordingStream)
        .thenAnswer((_) => const Stream<bool>.empty());
    when(() => mockRecordingBloc.stream)
        .thenAnswer((_) => const Stream<RecordingState>.empty());
    when(() => mockRecordingBloc.state).thenReturn(const RecordingState(
      isRecording: false,
      currentTrack: null,
      selectedSenseBox: null,
      lastRecordingStopTimestamp: null,
      pendingBatchUploadRequest: null,
    ));
  });

  Future<void> pumpTracksScreen(WidgetTester tester, Locale locale) async {
    when(() => mockTrackService.getAllTracks())
        .thenAnswer((_) async => <TrackData>[]);
    when(() => mockTrackService.getTracksPaginated(
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          skipLastTrack: any(named: 'skipLastTrack'),
        )).thenAnswer((_) async => <TrackData>[]);

    // Mock OpenSenseMapBloc dependencies
    final mockOpenSenseMapBloc = MockOpenSenseMapBloc();
    when(() => mockOpenSenseMapBloc.openSenseMapService)
        .thenReturn(MockOpenSenseMapService());
    when(() => mockOpenSenseMapBloc.stream)
        .thenAnswer((_) => const Stream<OpenSenseMapState>.empty());
    when(() => mockOpenSenseMapBloc.state).thenReturn(const OpenSenseMapState(
      isAuthenticated: false,
      isAuthenticating: false,
      selectedSenseBox: null,
      senseBoxes: <dynamic>[],
    ));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: MultiProvider(
          providers: [
            BlocProvider<TrackBloc>.value(
              value: mockTrackBloc,
            ),
            BlocProvider<RecordingBloc>.value(
              value: mockRecordingBloc,
            ),
            BlocProvider<OpenSenseMapBloc>.value(
              value: mockOpenSenseMapBloc,
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

    testWidgets("is translated in French", (WidgetTester tester) async {
      await pumpTracksScreen(tester, const Locale('fr'));
      expect(find.text('Vos parcours'), findsOneWidget);
    });
  });
}
