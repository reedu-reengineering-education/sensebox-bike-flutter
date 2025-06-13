import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../test_helpers.dart';

class MockLaunchUrl extends Mock {
  Future<bool> call(Uri url, {LaunchMode mode});
}

class MockTrackBloc extends Mock implements TrackBloc {}

class MockIsarService extends Mock implements IsarService {}

void main() {
  Provider.debugCheckInvalidValueType = null;

  late MockLaunchUrl mockLaunchUrl;
  late SettingsBloc mockSettingsBloc;
  late MockTrackBloc mockTrackBloc;
  late MockIsarService mockIsarService;

  setUpAll(() {
    // Register fallback values for Uri and LaunchMode
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(LaunchMode.externalApplication);

    const sharedPreferencesChannel =
        MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharedPreferencesChannel,
            (MethodCall call) async {
      if (call.method == 'getAll') {
        return <String,
            dynamic>{}; // Return an empty map for shared preferences
      }
      return null;
    });
  });

  setUp(() {
    mockLaunchUrl = MockLaunchUrl();
    mockSettingsBloc = SettingsBloc();
    mockTrackBloc = MockTrackBloc();
    mockIsarService = MockIsarService();

    when(() => mockTrackBloc.isarService).thenReturn(mockIsarService);
  });

  testWidgets('launches correct URLs when buttons are tapped',
      (WidgetTester tester) async {
    when(() => mockLaunchUrl.call(any(), mode: any(named: 'mode')))
        .thenAnswer((_) async => true);

    await tester.pumpWidget(
      createLocalizedTestApp(
      locale: const Locale('en'),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsBloc>.value(value: mockSettingsBloc),
            Provider<TrackBloc>.value(value: mockTrackBloc),
          ],
        child: SettingsScreen(launchUrlFunction: mockLaunchUrl.call),
      ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Privacy Policy'), 100.0);
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    verify(() => mockLaunchUrl.call(
          Uri.parse(senseBoxBikePrivacyPolicyUrl),
          mode: any(named: 'mode'),
        )).called(1);

    await tester.scrollUntilVisible(find.text('E-mail'), 100.0);
    await tester.tap(find.text('E-mail'));
    await tester.pumpAndSettle();

    verify(() => mockLaunchUrl.call(
          Uri.parse('mailto:$contactEmail?subject=senseBox:bike%20App'),
          mode: any(named: 'mode'),
        )).called(1);

    await tester.scrollUntilVisible(find.text('GitHub issue'), 100.0);
    await tester.tap(find.text('GitHub issue'));
    await tester.pumpAndSettle();

    verify(() => mockLaunchUrl.call(
          Uri.parse(gitHubNewIssueUrl),
          mode: any(named: 'mode'),
        )).called(1);
  });
  testWidgets('shows confirmation dialog and deletes data when confirmed',
      (WidgetTester tester) async {
    when(() => mockIsarService.deleteAllData()).thenAnswer((_) async {});

    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsBloc>.value(value: mockSettingsBloc),
            Provider<TrackBloc>.value(value: mockTrackBloc),
          ],
          child: const SettingsScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Delete All Data'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'Are you sure you want to delete all data? This action is irreversible.'),
        findsOneWidget);

    await tester.tap(find.text('Ok'));
    await tester.pumpAndSettle();

    verify(() => mockIsarService.deleteAllData()).called(1);
    expect(
        find.text('All data has been successfully deleted.'), findsOneWidget);
  });

  testWidgets('shows confirmation dialog and cancels deletion when canceled',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsBloc>.value(value: mockSettingsBloc),
            Provider<TrackBloc>.value(value: mockTrackBloc),
          ],
          child: const SettingsScreen(),
        ),
      ),
    );
    await tester.tap(find.text('Delete All Data'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'Are you sure you want to delete all data? This action is irreversible.'),
        findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => mockIsarService.deleteAllData());
  });
}