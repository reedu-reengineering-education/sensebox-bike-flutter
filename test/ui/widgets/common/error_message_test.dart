import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/common/error_message.dart';
import '../../../test_helpers.dart';

void main() {
  group('ErrorMessage', () {
    testWidgets('displays title text', (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: ErrorMessage(
              icon: Icons.error_outline,
              title: 'Error Title',
            ),
          ),
        ),
      );

      expect(find.text('Error Title'), findsOneWidget);
    });

    testWidgets('displays detail text when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: ErrorMessage(
              icon: Icons.error_outline,
              title: 'Error Title',
              detail: 'Error detail message',
            ),
          ),
        ),
      );

      expect(find.text('Error Title'), findsOneWidget);
      expect(find.text('Error detail message'), findsOneWidget);
    });

    testWidgets('does not display detail when not provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: ErrorMessage(
              icon: Icons.error_outline,
              title: 'Error Title',
            ),
          ),
        ),
      );

      expect(find.text('Error Title'), findsOneWidget);
      expect(find.byType(Padding), findsNWidgets(1));
    });

    testWidgets('displays error icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: ErrorMessage(
              icon: Icons.error_outline,
              title: 'Error Title',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}

