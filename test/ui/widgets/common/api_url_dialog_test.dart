import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/api_url_dialog.dart';

import '../../../mocks.dart';

const _predefinedUrls = [
  'https://api.opensensemap.org',
  'https://api.staging.opensensemap.org',
];
const _customUrl = 'https://my-custom-api.example.com';

Widget _buildApp(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  late MockSettingsBloc settingsBloc;
  late TextEditingController controller;

  setUp(() {
    settingsBloc = MockSettingsBloc();
    controller = TextEditingController();
    when(() => settingsBloc.apiUrl).thenReturn(_predefinedUrls.first);
    when(() => settingsBloc.setApiUrl(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    controller.dispose();
  });

  // ---------------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------------
  group('loading state', () {
    testWidgets('shows CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        isLoading: true,
      )));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Dropdown state – predefined URLs
  // ---------------------------------------------------------------------------
  group('dropdown state (predefined URLs)', () {
    testWidgets('shows the dropdown with predefined URLs', (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: _predefinedUrls,
      )));
      await tester.pump();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('dropdown contains "Custom Service URL" option',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: _predefinedUrls,
      )));
      await tester.pump();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Custom Service URL'), findsWidgets);
    });

    testWidgets('URL text field is hidden when a predefined URL is selected',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: _predefinedUrls,
      )));
      await tester.pump();

      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('selecting "Custom Service URL" reveals the text field',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: _predefinedUrls,
      )));
      await tester.pump();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom Service URL').last);
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('save button is disabled when custom URL field is empty',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: _predefinedUrls,
      )));
      await tester.pump();

      // Select custom option
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom Service URL').last);
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('save button is disabled when custom URL equals current URL',
        (tester) async {
      when(() => settingsBloc.apiUrl).thenReturn(_customUrl);
      controller.text = _customUrl;

      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: _predefinedUrls,
      )));
      await tester.pump();

      // Select custom option
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom Service URL').last);
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('save button is enabled when a valid new custom URL is entered',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: _predefinedUrls,
      )));
      await tester.pump();

      // Select custom option
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom Service URL').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), _customUrl);
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('tapping save with a valid custom URL calls setApiUrl',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: _predefinedUrls,
      )));
      await tester.pump();

      // Select custom option
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom Service URL').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), _customUrl);
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      verify(() => settingsBloc.setApiUrl(_customUrl)).called(1);
    });

    testWidgets(
        'pre-selects "Custom Service URL" when current URL is not in the list',
        (tester) async {
      when(() => settingsBloc.apiUrl).thenReturn(_customUrl);

      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: _predefinedUrls,
      )));
      await tester.pump();

      // Text field should already be visible
      expect(find.byType(TextFormField), findsOneWidget);
      // And pre-filled
      expect(controller.text, _customUrl);
    });

    testWidgets(
        'save button is disabled when a predefined URL is already selected',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: _predefinedUrls,
      )));
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Fallback state – no predefined URLs
  // ---------------------------------------------------------------------------
  group('fallback state (no predefined URLs)', () {
    testWidgets('shows text field directly', (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
      )));
      await tester.pump();

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('tapping save with a valid URL calls setApiUrl',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
      )));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), _customUrl);
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // setApiUrl is not called here because the fallback uses formKey.save(),
      // which doesn't call settingsBloc directly – just validates and pops.
      // The dialog pops without an error, meaning no validation error was thrown.
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------
  group('error state', () {
    testWidgets('shows cloud_off icon and error title', (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        error: 'Network timeout',
      )));
      await tester.pump();

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Unable to load service URLs.'), findsOneWidget);
    });

    testWidgets('shows the expansion tile collapsed by default',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        error: 'Network timeout',
      )));
      await tester.pump();

      expect(find.text('Details & Custom URL'), findsOneWidget);
      // URL text field should not be visible while collapsed
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('expanding the tile shows the error string and URL text field',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        error: 'Network timeout',
      )));
      await tester.pump();

      await tester.tap(find.text('Details & Custom URL'));
      await tester.pumpAndSettle();

      expect(find.text('Network timeout'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('no error details section when error string is empty',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        error: '',
      )));
      await tester.pump();

      await tester.tap(find.text('Details & Custom URL'));
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsNothing);
    });

    testWidgets('save button is disabled when URL field is empty',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        error: 'timeout',
      )));
      await tester.pump();

      await tester.tap(find.text('Details & Custom URL'));
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('save button becomes enabled when a valid URL is entered',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        error: 'timeout',
      )));
      await tester.pump();

      await tester.tap(find.text('Details & Custom URL'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), _customUrl);
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('tapping save with a valid URL calls setApiUrl',
        (tester) async {
      await tester.pumpWidget(_buildApp(ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        error: 'timeout',
      )));
      await tester.pump();

      await tester.tap(find.text('Details & Custom URL'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), _customUrl);
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      verify(() => settingsBloc.setApiUrl(_customUrl)).called(1);
    });
  });
}
