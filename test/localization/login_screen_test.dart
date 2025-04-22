import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/common/email_field.dart';
import 'package:sensebox_bike/ui/widgets/common/error_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/password_field.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/register.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../mocks.dart';
import '../test_helpers.dart';

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late OpenSenseMapBloc mockBloc;
  late MockNavigatorObserver mockObserver;

  setUpAll(() {
    disableProviderDebugChecks();
    initializeTestDependencies();

    registerFallbackValue('test@example.com');
    registerFallbackValue('password123');
  });

  setUp(() {
    mockBloc = MockOpenSenseMapBloc();
    mockObserver = MockNavigatorObserver();
  });

  Widget buildTestWidget(Widget child, Locale locale) {
    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Provider<OpenSenseMapBloc>.value(
        value: mockBloc,
        child: Scaffold(
          body: child,
        ),
      ),
      navigatorObservers: [mockObserver],
    );
  }

  group('LoginForm', () {
    testWidgets('renders login form with all fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(LoginForm(bloc: mockBloc), const Locale('en')));

      expect(find.byType(EmailField), findsOneWidget);
      expect(find.byType(PasswordField), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('is translated in German', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(LoginForm(bloc: mockBloc), const Locale('de')));

      expect(find.text('Anmelden'), findsOneWidget);
    });

    testWidgets('is translated in Portuguese', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(LoginForm(bloc: mockBloc), const Locale('pt')));

      expect(find.text('Entrar'), findsOneWidget);
    });
  });

  group('RegisterForm', () {
    testWidgets('renders register form with all fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(RegisterForm(bloc: mockBloc), const Locale('en')));

      expect(find.byType(TextFormField), findsNWidgets(4)); // Name, Email, Password, Confirm Password
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('is translated in German', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(RegisterForm(bloc: mockBloc), const Locale('de')));

      expect(find.text('Registrieren'), findsOneWidget);
    });

    testWidgets('is translated in Portuguese', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(RegisterForm(bloc: mockBloc), const Locale('pt')));

      expect(find.text('Registrar-se'), findsOneWidget);
    });
  });
}