import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/common/labeled_text_form_field.dart';
import '../../../test_helpers.dart';

void main() {
  group('LabeledTextFormField', () {
    testWidgets('displays initial value', (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              child: LabeledTextFormField(
                labelText: 'Test Label',
                initialValue: 'Initial Text',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Initial Text'), findsOneWidget);
    });

    testWidgets('updates value when user types', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              key: formKey,
              child: LabeledTextFormField(
                labelText: 'Test Label',
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'New Text');
      await tester.pump();

      expect(find.text('New Text'), findsOneWidget);
    });

    testWidgets('shows error text when validation fails', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              key: formKey,
              child: LabeledTextFormField(
                labelText: 'Test Label',
                validator: (value) => value == null || value.isEmpty ? 'Error' : null,
              ),
            ),
          ),
        ),
      );

      formKey.currentState?.validate();
      await tester.pump();

      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('respects enabled state', (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              child: LabeledTextFormField(
                labelText: 'Test Label',
                enabled: false,
              ),
            ),
          ),
        ),
      );

      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('calls onSaved when form is saved', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      String? savedValue;

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              key: formKey,
              child: LabeledTextFormField(
                labelText: 'Test Label',
                onSaved: (value) {
                  savedValue = value;
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Test Value');
      await tester.pump();

      formKey.currentState?.save();
      await tester.pump();

      expect(savedValue, equals('Test Value'));
    });

  });
}

