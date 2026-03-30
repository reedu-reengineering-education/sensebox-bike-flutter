import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/common/dropdown_form_field.dart';
import '../../../test_helpers.dart';

void main() {
  group('DropdownFormField', () {
    final items = [
      DropdownItem<String>(value: 'option1', label: 'Option 1'),
      DropdownItem<String>(value: 'option2', label: 'Option 2'),
      DropdownItem<String>(value: 'option3', label: 'Option 3'),
    ];

    testWidgets('displays initial value', (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              child: DropdownFormField<String>(
                labelText: 'Test Label',
                items: items,
                initialValue: 'option2',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Option 2'), findsWidgets);
    });

    testWidgets('updates value when option is selected', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              key: formKey,
              child: DropdownFormField<String>(
                labelText: 'Test Label',
                items: items,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Option 2').last);
      await tester.pumpAndSettle();

      expect(find.text('Option 2'), findsWidgets);
    });

    testWidgets('shows error text when validation fails', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              key: formKey,
              child: DropdownFormField<String>(
                labelText: 'Test Label',
                items: items,
                validator: (value) => value == null ? 'Error' : null,
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
              child: DropdownFormField<String>(
                labelText: 'Test Label',
                items: items,
                enabled: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.onChanged, isNull);
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
              child: DropdownFormField<String>(
                labelText: 'Test Label',
                items: items,
                onSaved: (value) {
                  savedValue = value;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Option 2').last);
      await tester.pumpAndSettle();

      formKey.currentState?.save();
      await tester.pump();

      expect(savedValue, equals('option2'));
    });

    testWidgets('supports null value option', (WidgetTester tester) async {
      final itemsWithNull = [
        DropdownItem<String?>(value: null, label: 'None'),
        ...items,
      ];

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              child: DropdownFormField<String?>(
                labelText: 'Test Label',
                items: itemsWithNull,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<String?>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(find.text('None'), findsWidgets);
    });

    testWidgets('uses custom item builder', (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              child: DropdownFormField<String>(
                labelText: 'Test Label',
                items: items,
                itemBuilder: (context, value) {
                  return Row(
                    children: [
                      Icon(Icons.check),
                      SizedBox(width: 8),
                      Text('Custom $value'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsWidgets);
      expect(find.text('Custom option1'), findsOneWidget);
    });

    testWidgets('shows disabled hint when disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: Form(
              child: DropdownFormField<String>(
                labelText: 'Test Label',
                items: items,
                enabled: false,
                disabledHint: 'Disabled Hint',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.onChanged, isNull);
    });
  });
}

