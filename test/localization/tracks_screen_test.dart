import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../mocks.dart';

void main() {
  testWidgets('TracksScreen localization test', (WidgetTester tester) async {
    // Mock dependencies - this will be important later!
    final mockIsarService = MockIsarService();

    // Function to create the widget with a specific locale
    Widget createWidgetUnderTest(Locale locale) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
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

    // Test with English locale
    await tester.pumpWidget(createWidgetUnderTest(const Locale('en')));
    expect(find.text('Tracks'), findsOneWidget); // Or whatever the English title is

    // Test with German locale
    await tester.pumpWidget(createWidgetUnderTest(const Locale('de')));
    expect(find.text('Tracks'), findsOneWidget); // Or whatever the German title is

    // Test with Portugese locale
    await tester.pumpWidget(createWidgetUnderTest(const Locale('pt')));
    expect(find.text('Trajetos'), findsOneWidget); // Or whatever the German title is
  });
}
