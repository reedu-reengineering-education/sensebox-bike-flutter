import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/common/api_url_field.dart';

void main() {
  group('ApiUrlField Widget Tests', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('should display with default properties', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiUrlField(controller: controller),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('API URL'), findsOneWidget);
    });

    testWidgets('should display custom label text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiUrlField(
              controller: controller,
              labelText: 'Custom API URL',
            ),
          ),
        ),
      );

      expect(find.text('Custom API URL'), findsOneWidget);
    });

    testWidgets('should display helper text when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiUrlField(
              controller: controller,
              helperText: 'Enter your custom API endpoint',
            ),
          ),
        ),
      );

      expect(find.text('Enter your custom API endpoint'), findsOneWidget);
    });

    testWidgets('should display default value as hint text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiUrlField(
              controller: controller,
              defaultValue: 'https://custom-api.example.com',
            ),
          ),
        ),
      );

      // Check that the hint text is displayed
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.hintText, 'https://custom-api.example.com');
    });

    testWidgets('should use default hint text when no default value provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiUrlField(controller: controller),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.hintText, 'https://api.opensensemap.org');
    });

    testWidgets('should have correct keyboard type', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiUrlField(controller: controller),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, TextInputType.url);
    });

    testWidgets('should have correct text input action', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiUrlField(controller: controller),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textInputAction, TextInputAction.done);
    });

    testWidgets('should validate empty input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: ApiUrlField(controller: controller),
            ),
          ),
        ),
      );

      // Trigger validation by trying to submit the form
      final form = tester.widget<Form>(find.byType(Form));
      final formKey = form.key as GlobalKey<FormState>;
      
      formKey.currentState?.validate();
      await tester.pump();

      // Should show validation error
      expect(find.text('Please enter a valid URL (e.g., https://api.opensensemap.org)'), findsOneWidget);
    });

    testWidgets('should validate invalid URL format', (WidgetTester tester) async {
      controller.text = 'invalid-url';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: ApiUrlField(controller: controller),
            ),
          ),
        ),
      );

      // Trigger validation
      final form = tester.widget<Form>(find.byType(Form));
      final formKey = form.key as GlobalKey<FormState>;
      
      formKey.currentState?.validate();
      await tester.pump();

      // Should show validation error
      expect(find.text('Please enter a valid URL (e.g., https://api.opensensemap.org)'), findsOneWidget);
    });

    testWidgets('should accept valid URL', (WidgetTester tester) async {
      controller.text = 'https://api.example.com';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: ApiUrlField(controller: controller),
            ),
          ),
        ),
      );

      // Trigger validation
      final form = tester.widget<Form>(find.byType(Form));
      final formKey = form.key as GlobalKey<FormState>;
      
      final isValid = formKey.currentState?.validate();
      await tester.pump();

      // Should be valid
      expect(isValid, true);
      expect(find.text('Please enter a valid URL (e.g., https://api.opensensemap.org)'), findsNothing);
    });

    testWidgets('should accept HTTP URL', (WidgetTester tester) async {
      controller.text = 'http://api.example.com';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: ApiUrlField(controller: controller),
            ),
          ),
        ),
      );

      // Trigger validation
      final form = tester.widget<Form>(find.byType(Form));
      final formKey = form.key as GlobalKey<FormState>;
      
      final isValid = formKey.currentState?.validate();
      await tester.pump();

      // Should be valid
      expect(isValid, true);
    });

    testWidgets('should use custom validator when provided', (WidgetTester tester) async {
      String? customValidator(String? value) {
        if (value == null || value.isEmpty) {
          return 'Custom error message';
        }
        return null;
      }
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: ApiUrlField(
                controller: controller,
                validator: customValidator,
              ),
            ),
          ),
        ),
      );

      // Trigger validation
      final form = tester.widget<Form>(find.byType(Form));
      final formKey = form.key as GlobalKey<FormState>;
      
      formKey.currentState?.validate();
      await tester.pump();

      // Should show custom error message
      expect(find.text('Custom error message'), findsOneWidget);
    });

    testWidgets('should have fixed width of 300', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiUrlField(controller: controller),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 300);
    });
  });
}
