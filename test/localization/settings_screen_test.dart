import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';

void main() {

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

  group("SettingsScreen Widget", () {
    late SettingsBloc mockSettingsBloc;

    setUp(() {
      mockSettingsBloc = SettingsBloc();
    });

    Widget createTestApp(Locale locale) {
      return MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: ChangeNotifierProvider<SettingsBloc>.value(
          value: mockSettingsBloc,
          child: const SettingsScreen(),
        ),
      );
    }

    testWidgets("is translated in English", (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const Locale('en')));

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Vibrate on disconnect'), findsOneWidget);
      expect(find.text('Privacy Zones'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Contact'), findsOneWidget);
    });
    testWidgets("is translated in German", (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const Locale('de')));

      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Allgemeine'), findsOneWidget);
      expect(find.text('Vibration bei Verbindungsabbruch'), findsOneWidget);
      expect(find.text('Privatzonen'), findsOneWidget);
      expect(find.text('Andere'), findsOneWidget);
      expect(find.text('Über die App'), findsOneWidget);
      expect(find.text('Datenschutz'), findsOneWidget);
      expect(find.text('Kontakt'), findsOneWidget);
    });
    testWidgets("is translated in Portugese", (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const Locale('pt')));

      expect(find.text('Configurações'), findsOneWidget);
      expect(find.text('Geral'), findsOneWidget);
      expect(find.text('Vibrar ao desconectar'), findsOneWidget);
      expect(find.text('Áreas de Privacidade'), findsOneWidget);
      expect(find.text('Outros'), findsOneWidget);
      expect(find.text('Sobre'), findsOneWidget);
      expect(find.text('Política de Privacidade'), findsOneWidget);
      expect(find.text('Contato'), findsOneWidget);
    });
    
  });
}