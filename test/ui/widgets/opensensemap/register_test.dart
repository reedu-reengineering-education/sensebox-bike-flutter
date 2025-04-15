import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/register.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../test_helpers.dart';

class MockOpenSenseMapBloc extends Mock implements OpenSenseMapBloc {}
void main() {
  late MockOpenSenseMapBloc mockBloc;

  setUp(() {
    initializeTestDependencies();
    mockBloc = MockOpenSenseMapBloc();

    // Mock the isAuthenticated property
    when(() => mockBloc.isAuthenticated).thenReturn(false);
  });

  Widget createTestWidget() {
    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: RegisterForm(bloc: mockBloc),
      ),
    );
  }

  Future<void> enterTextData (WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(1), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
  }
  testWidgets('renders RegisterForm with all fields', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('Register'), findsOneWidget);
  });

  testWidgets('shows error when privacy policy checkbox is not checked', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await enterTextData(tester);
    await tester.tap(find.textContaining('Register'));
    await tester.pump();

    expect(find.text('You must accept the privacy policy'), findsOneWidget);
  });

  testWidgets('does not show error when privacy policy checkbox is checked', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await enterTextData(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.tap(find.textContaining('Register'));
    await tester.pump();

    expect(find.text('You must accept the privacy policy'), findsNothing);
  });

  testWidgets('calls register method on valid form submission', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await enterTextData(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    when(() => mockBloc.register(any(), any(), any())).thenAnswer((_) async => {});

    await tester.tap(find.textContaining('Register'));
    await tester.pump();

    verify(() => mockBloc.register('Test User', 'test@example.com', 'password123')).called(1);
  });

  testWidgets('displays loading indicator during registration', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await enterTextData(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    when(() => mockBloc.register(any(), any(), any())).thenAnswer((_) async {
      await Future.delayed(const Duration(seconds: 1));
    });

    await tester.tap(find.textContaining('Register'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('shows error dialog on registration failure', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await enterTextData(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    when(() => mockBloc.register(any(), any(), any())).thenThrow(Exception('Registration failed'));

    await tester.tap(find.textContaining('Register'));
    await tester.pump();

    expect(find.text('Registration failed'), findsOneWidget);
  });
}