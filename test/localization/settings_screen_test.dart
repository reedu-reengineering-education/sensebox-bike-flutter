import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';

import '../test_helpers.dart';

class MockIsarService extends Mock implements IsarService {}

class MockTrackBloc extends Mock implements TrackBloc {}

void main() {
  late MockIsarService mockIsarService;
  late MockTrackBloc mockTrackBloc;
  late SettingsBloc mockSettingsBloc;

  setUpAll(() {
    // Register fallback values for complex types
    registerFallbackValue(TrackData());
    registerFallbackValue(Duration.zero);

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

    initializeTestDependencies();
  });

  setUp(() {
    mockIsarService = MockIsarService();
    mockTrackBloc = MockTrackBloc();
    mockSettingsBloc = SettingsBloc();

    // Setup service mocks
    when(() => mockTrackBloc.isarService).thenReturn(mockIsarService);
    when(() => mockIsarService.trackService.getAllTracks())
        .thenAnswer((_) async => [TrackData()]);
  });

  Widget buildTestWidget(Locale locale) {
    return createLocalizedTestApp(
      locale: locale,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsBloc>.value(value: mockSettingsBloc),
          ChangeNotifierProvider<TrackBloc>.value(value: mockTrackBloc),
        ],
        child: const SettingsScreen(),
      ),
    );
  }

  group("SettingsScreen Widget", () {
    testWidgets("is translated in English", (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Vibrate on disconnect'), findsOneWidget);
      expect(find.text('Privacy Zones'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Privacy Policy'),
        200.0,
      );
      await tester.pumpAndSettle();

      expect(find.text('Help or feedback?'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('GitHub issue'), findsOneWidget);
    });

    testWidgets("is translated in German", (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(const Locale('de')));
      await tester.pumpAndSettle();

      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Allgemeine'), findsOneWidget);
      expect(find.text('Vibration bei Verbindungsabbruch'), findsOneWidget);
      expect(find.text('Privatzonen'), findsOneWidget);
      expect(find.text('Andere'), findsOneWidget);
      expect(find.text('Über die App'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Datenschutz'),
        200.0,
      );
      await tester.pumpAndSettle();

      expect(find.text('Hilfe oder Feedback?'), findsOneWidget);
      expect(find.text('E-Mail'), findsOneWidget);
      expect(find.text('GitHub issue'), findsOneWidget);
    });

    testWidgets("is translated in Portuguese", (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(const Locale('pt')));
      await tester.pumpAndSettle();

      expect(find.text('Configurações'), findsOneWidget);
      expect(find.text('Geral'), findsOneWidget);
      expect(find.text('Vibrar ao desconectar'), findsOneWidget);
      expect(find.text('Áreas de Privacidade'), findsOneWidget);
      expect(find.text('Outros'), findsOneWidget);
      expect(find.text('Sobre'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Política de Privacidade'),
        200.0,
      );
      await tester.pumpAndSettle();

      expect(find.text('Ajuda ou feedback?'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('GitHub issue'), findsOneWidget);
    });
  });
}
