import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/ui/screens/track_detail_screen.dart';

import '../../mocks.dart';

class _MockIsarServiceWithGeolocation extends Mock implements IsarService {
  final MockTrackService mockTrackService = MockTrackService();
  final MockGeolocationService mockGeolocationService = MockGeolocationService();

  @override
  TrackService get trackService => mockTrackService;

  @override
  GeolocationService get geolocationService => mockGeolocationService;
}

class _MockOpenSenseMapService extends Mock implements OpenSenseMapService {}

void main() {
  late _MockIsarServiceWithGeolocation mockIsarService;
  late TrackBloc trackBloc;
  late MockOpenSenseMapBloc mockOpenSenseMapBloc;
  late MockSettingsBloc mockSettingsBloc;

  setUpAll(() {
    registerFallbackValue(TrackData());
    dotenv.testLoad(fileInput: 'MAPBOX_ACCESS_TOKEN=test_token');
  });

  setUp(() {
    mockIsarService = _MockIsarServiceWithGeolocation();
    trackBloc = TrackBloc(mockIsarService);
    mockOpenSenseMapBloc = MockOpenSenseMapBloc();
    mockSettingsBloc = MockSettingsBloc();

    when(() => mockOpenSenseMapBloc.openSenseMapService)
        .thenReturn(_MockOpenSenseMapService());
    when(() => mockOpenSenseMapBloc.hasAuthAndSelectedSenseBox)
        .thenReturn(false);
    when(() => mockSettingsBloc.directUploadMode).thenReturn(true);
  });

  tearDown(() {
    trackBloc.dispose();
  });

  Future<void> pumpTrackDetail(
    WidgetTester tester,
    TrackData track,
    List<GeolocationData> geolocations,
  ) async {
    when(() => mockIsarService.mockTrackService.getTrackById(track.id))
        .thenAnswer((_) async => track);
    when(() => mockIsarService.mockGeolocationService
            .getGeolocationDataWithPreloadedSensors(track.id))
        .thenAnswer((_) async => geolocations);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<TrackBloc>.value(value: trackBloc),
            ChangeNotifierProvider<OpenSenseMapBloc>.value(
              value: mockOpenSenseMapBloc,
            ),
            ChangeNotifierProvider<SettingsBloc>.value(
              value: mockSettingsBloc,
            ),
          ],
          child: TrackDetailScreen(track: track),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  group('TrackDetailScreen collection mode', () {
    testWidgets('shows sampling row for onTap track', (tester) async {
      final geolocations = [
        TestTrackBuilder.createGeolocation(),
      ];
      final track = TestTrackBuilder.createTrack(
        dataCollectionMode: DataCollectionMode.onTap.toJson(),
        geolocations: geolocations,
      );

      await pumpTrackDetail(tester, track, geolocations);

      expect(find.text('Sampling'), findsOneWidget);
      expect(find.text('Manual sampling'), findsOneWidget);
    });

    testWidgets('does not show sampling row for legacy track', (tester) async {
      final geolocations = [
        TestTrackBuilder.createGeolocation(),
      ];
      final track = TestTrackBuilder.createTrack(geolocations: geolocations);

      await pumpTrackDetail(tester, track, geolocations);

      expect(find.text('Sampling'), findsNothing);
      expect(find.text('Manual sampling'), findsNothing);
      expect(find.textContaining('Every'), findsNothing);
    });
  });
}
