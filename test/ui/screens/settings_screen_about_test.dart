import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../mocks.dart';
import '../../test_helpers.dart';

class MockIsarService extends Mock implements IsarService {}

class MockTrackBloc extends Mock implements TrackBloc {}

void main() {
  late MockIsarService mockIsarService;
  late MockTrackBloc mockTrackBloc;
  late SettingsBloc settingsBloc;
  late MockOpenSenseMapBloc mockOpenSenseMapBloc;

  setUpAll(() {
    registerFallbackValue(TrackData());

    initializeTestDependencies();

    PackageInfo.setMockInitialValues(
      appName: 'senseBox Bike',
      packageName: 'de.reedu.senseboxbike',
      version: '3.4.0',
      buildNumber: '340',
      buildSignature: 'test',
    );
  });

  setUp(() {
    mockIsarService = MockIsarService();
    mockTrackBloc = MockTrackBloc();
    settingsBloc = SettingsBloc();
    mockOpenSenseMapBloc = MockOpenSenseMapBloc();

    when(() => mockTrackBloc.isarService).thenReturn(mockIsarService);
    when(() => mockIsarService.trackService.getAllTracks())
        .thenAnswer((_) async => [TrackData()]);
  });

  tearDown(() {
    settingsBloc.dispose();
  });

  Widget buildTestWidget({
    Future<bool> Function(Uri url, {LaunchMode mode})? launchUrlFunction,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsBloc>.value(value: settingsBloc),
        ChangeNotifierProvider<TrackBloc>.value(value: mockTrackBloc),
        ChangeNotifierProvider<OpenSenseMapBloc>.value(value: mockOpenSenseMapBloc),
        ChangeNotifierProvider<ConfigurationBloc>.value(value: ConfigurationBloc()),
      ],
      child: createLocalizedTestApp(
        locale: const Locale('en'),
        child: SettingsScreen(
          launchUrlFunction:
              launchUrlFunction ??
              (Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async =>
                  true,
        ),
      ),
    );
  }

  testWidgets('opens privacy policy from About section', (tester) async {
    Uri? launchedUrl;

    await tester.pumpWidget(
      buildTestWidget(
        launchUrlFunction:
            (url, {LaunchMode mode = LaunchMode.platformDefault}) async {
          launchedUrl = url;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(launchedUrl, Uri.parse(senseBoxBikePrivacyPolicyUrl));
  });
}
