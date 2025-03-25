import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login_selection_modal.dart';

import '../mocks.dart';

void main() {
  Provider.debugCheckInvalidValueType = null;

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
  
  group('LoginSelectionModal', () {
    late OpenSenseMapBloc mockBloc;

    setUp(() {
      mockBloc = MockOpenSenseMapBloc();
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
        home: Provider<OpenSenseMapBloc>.value(
          value: mockBloc,
          child: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => showLoginOrSenseBoxSelection(context, mockBloc),
              child: const Text('Show Modal'),
            ),
          ),
        ),
      );
    }

    testWidgets('is translated in English', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const Locale('en')));
      // Tap the button to show the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify English text
      expect(find.text('Login'), findsNWidgets(2)); // There is a tab and button with this text
      expect(find.text('Register with openSenseMap'), findsOneWidget);
    });

    testWidgets('is translated in German', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const Locale('de')));
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify German text
      expect(find.text('Anmelden'), findsNWidgets(2));
      expect(find.text('Registrieren bei openSenseMap'), findsOneWidget);
    });

    testWidgets('is translated in Portugese', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const Locale('pt')));
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify German text
      expect(find.text('Entrar'), findsNWidgets(2));
      expect(find.text('Registrar-se no openSenseMap'), findsOneWidget);
    });
  });
}

