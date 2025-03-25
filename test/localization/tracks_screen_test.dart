import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';

import '../mocks.dart';

void main() {
  // The following setup is needed to allow running tests in GH actions
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock SharedPreferences
    const MethodChannel channel =
        MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{}; // Return an empty map or your mock data
        }
        return null;
      },
    );

    // Ensure SharedPreferences is initialized
    SharedPreferences.setMockInitialValues({});
  });
  group('TracksScreen Widget', () {
    late MockIsarService mockIsarService;

    setUp(() {
      mockIsarService = MockIsarService();
    });
    Widget createTestApp(Locale locale) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Provider<IsarService>(
          create: (_) => mockIsarService, // Provide the mock
          child: const TracksScreen(),
        ),
      );
    }

    testWidgets("is translated in English", (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const Locale('en')));
      expect(find.text('Tracks'), findsOneWidget);
    });

    testWidgets("is translated in German", (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const Locale('de')));
      expect(find.text('Tracks'), findsOneWidget);
    });

    testWidgets("is translated in Portugese", (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const Locale('pt')));
      expect(find.text('Trajetos'), findsOneWidget);
    });
  });
}
