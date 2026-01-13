import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/utils/common.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

void main() {
  Widget buildTestWidget(void Function(BuildContext) testBody) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          testBody(context);
          return const SizedBox.shrink();
        },
      ),
    );
  }

  group('emailValidator', () {
    testWidgets('returns error when email is null or empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = emailValidator(context, null);
        expect(
            result, AppLocalizations.of(context)!.openSenseMapEmailErrorEmpty);

        final resultEmpty = emailValidator(context, '');
        expect(resultEmpty,
            AppLocalizations.of(context)!.openSenseMapEmailErrorEmpty);
      }));
    });

    testWidgets('returns error when email is invalid',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = emailValidator(context, 'invalid-email');
        expect(result,
            AppLocalizations.of(context)!.openSenseMapEmailErrorInvalid);
      }));
    });

    testWidgets('returns null when email is valid',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = emailValidator(context, 'test@example.com');
        expect(result, null);
      }));
    });
  });

  group('passwordValidatorSimple', () {
    testWidgets('returns error when password is null or empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = passwordValidatorSimple(context, null);
        expect(result,
            AppLocalizations.of(context)!.openSenseMapPasswordErrorEmpty);

        final resultEmpty = passwordValidatorSimple(context, '');
        expect(resultEmpty,
            AppLocalizations.of(context)!.openSenseMapPasswordErrorEmpty);
      }));
    });

    testWidgets('returns null when password is valid',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = passwordValidatorSimple(context, 'password123');
        expect(result, null);
      }));
    });
  });

  group('passwordValidator', () {
    testWidgets('returns error when password is null or empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = passwordValidator(context, null);
        expect(result,
            AppLocalizations.of(context)!.openSenseMapPasswordErrorEmpty);

        final resultEmpty = passwordValidator(context, '');
        expect(resultEmpty,
            AppLocalizations.of(context)!.openSenseMapPasswordErrorEmpty);
      }));
    });

    testWidgets('returns error when password is less than 8 characters',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = passwordValidator(context, 'short');
        expect(
            result,
            AppLocalizations.of(context)!
                .openSenseMapRegisterPasswordErrorCharacters);
      }));
    });

    testWidgets('returns null when password is valid',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = passwordValidator(context, 'password123');
        expect(result, null);
      }));
    });
  });

  group('truncateBoxName', () {
    test('truncates box name longer than 10 characters', () {
      final result = truncateBoxName('VeryLongBoxName');
      expect(result, 'VeryLong...');
    });

    test('does not truncate box name shorter than or equal to 10 characters',
        () {
      final result = truncateBoxName('ShortName');
      expect(result, 'ShortName');
    });
  });

  group('boxNameValidator', () {
    testWidgets('returns error when value is null or empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = boxNameValidator(context, null);
        expect(result, AppLocalizations.of(context)!.createBoxNameError);

        final resultEmpty = boxNameValidator(context, '');
        expect(resultEmpty, AppLocalizations.of(context)!.createBoxNameError);
      }));
    });

    testWidgets('returns error when value is less than 2 characters',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = boxNameValidator(context, 'A');
        expect(result, AppLocalizations.of(context)!.createBoxNameError);
      }));
    });

    testWidgets('returns error when value is more than 50 characters',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final longName = 'A' * 51;
        final result = boxNameValidator(context, longName);
        expect(result, AppLocalizations.of(context)!.createBoxNameError);
      }));
    });

    testWidgets('returns null when value is valid',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = boxNameValidator(context, 'Valid Name');
        expect(result, null);
      }));
    });
  });

  group('parseCustomTags', () {
    test('returns empty list for empty input', () {
      final result = parseCustomTags('');
      expect(result, isEmpty);
    });

    test('parses single tag', () {
      final result = parseCustomTags('tag1');
      expect(result, ['tag1']);
    });

    test('parses multiple comma-separated tags', () {
      final result = parseCustomTags('tag1,tag2,tag3');
      expect(result, ['tag1', 'tag2', 'tag3']);
    });

    test('trims whitespace from tags', () {
      final result = parseCustomTags(' tag1 , tag2 , tag3 ');
      expect(result, ['tag1', 'tag2', 'tag3']);
    });

    test('filters out empty tags', () {
      final result = parseCustomTags('tag1,,tag2, ,tag3');
      expect(result, ['tag1', 'tag2', 'tag3']);
    });
  });
}
