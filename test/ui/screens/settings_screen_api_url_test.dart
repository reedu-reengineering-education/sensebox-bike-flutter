import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';

void main() {
  group('SettingsScreen API URL Selection', () {
    late SettingsBloc settingsBloc;
    late ConfigurationBloc configurationBloc;

    setUpAll(() {
      // Mock SharedPreferences
      const sharedPreferencesChannel =
          MethodChannel('plugins.flutter.io/shared_preferences');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharedPreferencesChannel,
              (MethodCall call) async {
        if (call.method == 'getAll') {
          return <String, dynamic>{};
        }
        if (call.method == 'setString') {
          return true;
        }
        return null;
      });
    });

    setUp(() {
      settingsBloc = SettingsBloc();
      configurationBloc = ConfigurationBloc();
      // Preload API URLs for test
      configurationBloc.apiUrls?.clear();
      configurationBloc.apiUrls?.addAll([
        'https://api.opensensemap.org',
        'https://staging.api.opensensemap.org',
      ]);
    });

    tearDown(() {
      settingsBloc.dispose();
    });

    testWidgets('shows and selects API URL from dropdown', (tester) async {
      final openSenseMapBloc = OpenSenseMapBloc(configurationBloc: configurationBloc);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsBloc),
            ChangeNotifierProvider.value(value: configurationBloc),
            ChangeNotifierProvider.value(value: openSenseMapBloc),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Service URL tile
      expect(find.text('Service URL'), findsOneWidget);
      await tester.tap(find.text('Service URL'));
      await tester.pumpAndSettle();

      // Dropdown with API URLs should appear
      expect(find.text('https://api.opensensemap.org'), findsWidgets);
      expect(find.text('https://staging.api.opensensemap.org'), findsOneWidget);

      // Select staging URL
      await tester.tap(find.text('https://staging.api.opensensemap.org').last);
      await tester.pumpAndSettle();

      // The selected API should be updated in the tile
      expect(find.text('https://staging.api.opensensemap.org'), findsWidgets);
    });

    testWidgets('falls back to manual entry if no API list', (tester) async {
      configurationBloc.apiUrls?.clear();
      // Optionally, if you want to simulate null, you could add a setter for apiUrls in ConfigurationBloc for testing, but clearing is usually enough.
      final openSenseMapBloc = OpenSenseMapBloc(configurationBloc: configurationBloc);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsBloc),
            ChangeNotifierProvider.value(value: configurationBloc),
            ChangeNotifierProvider.value(value: openSenseMapBloc),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Service URL tile
      await tester.tap(find.text('Service URL'));
      await tester.pumpAndSettle();

      // Manual entry field should appear
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'https://custom.api');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The selected API should be updated in the tile
      expect(find.text('https://custom.api'), findsWidgets);
    });
  });
}
