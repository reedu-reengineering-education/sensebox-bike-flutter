import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';

void main() {
  group("SettingsScreen Widget", () {
    testWidgets("is translated in English by default", (WidgetTester tester) async {
      final mockSettingsBloc = SettingsBloc();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChangeNotifierProvider<SettingsBloc>.value(
            value: mockSettingsBloc,
            child: const SettingsScreen(),
          ),
        ),
      );

      // Wait for any animations to complete
      await tester.pumpAndSettle();

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
      final mockSettingsBloc = SettingsBloc();
      
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('de'),
          home: ChangeNotifierProvider<SettingsBloc>.value(
            value: mockSettingsBloc,
            child: const SettingsScreen(),
          ),
        ),
      );

      // Wait for any animations to complete
      await tester.pumpAndSettle();

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
      final mockSettingsBloc = SettingsBloc();
      
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('pt'),
          home: ChangeNotifierProvider<SettingsBloc>.value(
            value: mockSettingsBloc,
            child: const SettingsScreen(),
          ),
        ),
      );

      // Wait for any animations to complete
      await tester.pumpAndSettle();

      expect(find.text('Configurações'), findsOneWidget);
      expect(find.text('Geral'), findsOneWidget);
      expect(find.text('Vibrar ao desconectar'), findsOneWidget);
      expect(find.text('Zonas de Privacidade'), findsOneWidget);
      expect(find.text('Outros'), findsOneWidget);
      expect(find.text('Sobre'), findsOneWidget);
      expect(find.text('Política de Privacidade'), findsOneWidget);
      expect(find.text('Contato'), findsOneWidget);
    });
  });
}