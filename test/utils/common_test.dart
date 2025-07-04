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
          return const SizedBox.shrink(); // Placeholder widget
        },
      ),
    );
  }

  group('emailValidator', () {
    testWidgets('returns error when email is null or empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = emailValidator(context, null);
        expect(result, 'Email must not be empty');

        final resultEmpty = emailValidator(context, '');
        expect(resultEmpty, 'Email must not be empty');
      }));
    });

    testWidgets('returns error when email is invalid',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = emailValidator(context, 'invalid-email');
        expect(result, 'Invalid email address');
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
        expect(result, 'Password must not be empty');

        final resultEmpty = passwordValidatorSimple(context, '');
        expect(resultEmpty, 'Password must not be empty');
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
        expect(result, 'Password must not be empty');

        final resultEmpty = passwordValidator(context, '');
        expect(resultEmpty, 'Password must not be empty');
      }));
    });

    testWidgets('returns error when password is less than 8 characters',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget((context) {
        final result = passwordValidator(context, 'short');
        expect(result, 'Password must contain at least 8 characters');
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
}
