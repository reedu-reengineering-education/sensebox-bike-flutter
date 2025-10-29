import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';

void main() {
  group('SettingsScreen Upload Mode Tests', () {
    late SettingsBloc settingsBloc;

    setUpAll(() {
      // Set up SharedPreferences mock
      const sharedPreferencesChannel =
          MethodChannel('plugins.flutter.io/shared_preferences');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharedPreferencesChannel,
              (MethodCall call) async {
        if (call.method == 'getAll') {
          return <String, dynamic>{}; // Return empty preferences
        }
        if (call.method == 'setBool') {
          return true; // Mock successful save
        }
        return null;
      });
    });

    setUp(() {
      settingsBloc = SettingsBloc();
    });

    tearDown(() {
      settingsBloc.dispose();
    });

    testWidgets('should display upload mode option with current selection',
        (WidgetTester tester) async {
      // Create a simple widget that just shows the upload mode option
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsBloc>.value(
            value: settingsBloc,
            child: Scaffold(
              body: StreamBuilder<bool>(
                stream: settingsBloc.directUploadModeStream,
                initialData: settingsBloc.directUploadMode,
                builder: (context, snapshot) {
                  final isDirectUpload = snapshot.data ?? false;
                  final uploadModeText = isDirectUpload
                      ? 'Direct Upload (Beta)'
                      : 'Post-Ride Upload';

                  return ListTile(
                    title: const Text('Upload Mode'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'Choose when to upload your data during recording'),
                        const SizedBox(height: 4),
                        Text(
                          'Current: $uploadModeText',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify upload mode option is displayed
      expect(find.text('Upload Mode'), findsOneWidget);
      expect(find.text('Choose when to upload your data during recording'),
          findsOneWidget);
      
      // Verify default mode is displayed
      expect(find.textContaining('Current: Post-Ride Upload'), findsOneWidget);
    });

    testWidgets('should update display when upload mode changes',
        (WidgetTester tester) async {
      // Create a simple widget that just shows the upload mode option
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsBloc>.value(
            value: settingsBloc,
            child: Scaffold(
              body: StreamBuilder<bool>(
                stream: settingsBloc.directUploadModeStream,
                initialData: settingsBloc.directUploadMode,
                builder: (context, snapshot) {
                  final isDirectUpload = snapshot.data ?? false;
                  final uploadModeText = isDirectUpload
                      ? 'Direct Upload (Beta)'
                      : 'Post-Ride Upload';

                  return ListTile(
                    title: const Text('Upload Mode'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'Choose when to upload your data during recording'),
                        const SizedBox(height: 4),
                        Text(
                          'Current: $uploadModeText',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.textContaining('Current: Post-Ride Upload'), findsOneWidget);

      // Change to direct upload mode
      await settingsBloc.toggleDirectUploadMode(true);
      await tester.pumpAndSettle();

      // Verify display updates
      expect(
          find.textContaining('Current: Direct Upload (Beta)'), findsOneWidget);
    });

    testWidgets('should show upload mode dialog with radio buttons',
        (WidgetTester tester) async {
      // Create a simple dialog widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Upload Mode'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RadioListTile<bool>(
                                title: const Text('Post-Ride Upload'),
                                subtitle: const Text(
                                    'Upload data after recording stops'),
                                value: false,
                                groupValue: settingsBloc.directUploadMode,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    settingsBloc.toggleDirectUploadMode(value);
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                              RadioListTile<bool>(
                                title: const Text('Direct Upload (Beta)'),
                                subtitle: const Text(
                                    'Upload data in real-time during recording (experimental)'),
                                value: true,
                                groupValue: settingsBloc.directUploadMode,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    settingsBloc.toggleDirectUploadMode(value);
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog appears with both options
      expect(find.text('Upload Mode'), findsOneWidget);
      expect(find.text('Post-Ride Upload'), findsOneWidget);
      expect(find.text('Direct Upload (Beta)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('should toggle upload mode correctly in settings bloc',
        (WidgetTester tester) async {
      // Test the settings bloc directly
      final initialValue = settingsBloc.directUploadMode;
      
      // Toggle to direct upload
      await settingsBloc.toggleDirectUploadMode(true);
      expect(settingsBloc.directUploadMode, true);

      // Toggle back to post-ride
      await settingsBloc.toggleDirectUploadMode(false);
      expect(settingsBloc.directUploadMode, false);
      
      // Toggle back to initial value
      await settingsBloc.toggleDirectUploadMode(initialValue);
      expect(settingsBloc.directUploadMode, initialValue);
    });
  });

  group('SettingsScreen API URL Tests', () {
    late SettingsBloc settingsBloc;

    setUpAll(() {
      // Set up SharedPreferences mock
      const sharedPreferencesChannel =
          MethodChannel('plugins.flutter.io/shared_preferences');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharedPreferencesChannel,
              (MethodCall call) async {
        if (call.method == 'getAll') {
          return <String, dynamic>{}; // Return empty preferences
        }
        if (call.method == 'setString') {
          return true; // Mock successful save
        }
        return null;
      });
    });

    setUp(() {
      settingsBloc = SettingsBloc();
    });

    tearDown(() {
      settingsBloc.dispose();
    });

    test('should return default API URL when no custom URL is set', () {
      expect(settingsBloc.apiUrl, 'https://api.opensensemap.org');
    });

    test('should return custom API URL when set', () async {
      const customUrl = 'https://custom-api.example.com';
      await settingsBloc.setApiUrl(customUrl);
      expect(settingsBloc.apiUrl, customUrl);
    });

    test('should return default API URL when empty string is set', () async {
      await settingsBloc.setApiUrl('');
      expect(settingsBloc.apiUrl, 'https://api.opensensemap.org');
    });

    test('should persist API URL setting', () async {
      const customUrl = 'https://test-api.example.com';
      await settingsBloc.setApiUrl(customUrl);
      expect(settingsBloc.apiUrl, customUrl);
    });
  });

  group('SettingsScreen API URL Validation Tests', () {
    late SettingsBloc settingsBloc;

    setUpAll(() {
      // Set up SharedPreferences mock
      const sharedPreferencesChannel =
          MethodChannel('plugins.flutter.io/shared_preferences');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharedPreferencesChannel,
              (MethodCall call) async {
        if (call.method == 'getAll') {
          return <String, dynamic>{}; // Return empty preferences
        }
        if (call.method == 'setString') {
          return true; // Mock successful save
        }
        return null;
      });
    });

    setUp(() {
      settingsBloc = SettingsBloc();
    });

    tearDown(() {
      settingsBloc.dispose();
    });

    testWidgets('should not save invalid URL when validation fails',
        (WidgetTester tester) async {
      const initialUrl = 'https://api.opensensemap.org';
      const invalidUrl = 'not-a-valid-url';

      // Set initial valid URL
      await settingsBloc.setApiUrl(initialUrl);
      expect(settingsBloc.apiUrl, initialUrl);

      // Create a form key and controller that will be used in the widget
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController(text: invalidUrl);

      // Create a widget with the form actually in the tree
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsBloc>.value(
            value: settingsBloc,
            child: Scaffold(
              body: Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: controller,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'URL is required';
                        }
                        final uri = Uri.tryParse(value);
                        if (uri == null ||
                            (!uri.hasScheme ||
                                (!uri.scheme.startsWith('http')))) {
                          return 'Please enter a valid URL';
                        }
                        return null;
                      },
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Try to validate and save
                        if (formKey.currentState?.validate() ?? false) {
                          settingsBloc.setApiUrl(controller.text);
                        }
                      },
                      child: const Text('Save Invalid URL'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Tap the button to trigger validation
      await tester.tap(find.text('Save Invalid URL'));
      await tester.pump();

      // The URL should not have changed because validation failed
      expect(settingsBloc.apiUrl, initialUrl);
      
      controller.dispose();
    });

    testWidgets('should save valid URL when validation passes',
        (WidgetTester tester) async {
      const initialUrl = 'https://api.opensensemap.org';
      const validUrl = 'https://custom-api.example.com';

      // Set initial URL
      await settingsBloc.setApiUrl(initialUrl);
      expect(settingsBloc.apiUrl, initialUrl);

      // Create a form key and controller that will be used in the widget
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController(text: validUrl);

      // Create a widget with the form actually in the tree
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsBloc>.value(
            value: settingsBloc,
            child: Scaffold(
              body: Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: controller,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'URL is required';
                        }
                        final uri = Uri.tryParse(value);
                        if (uri == null ||
                            (!uri.hasScheme ||
                                (!uri.scheme.startsWith('http')))) {
                          return 'Please enter a valid URL';
                        }
                        return null;
                      },
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Try to validate and save
                        if (formKey.currentState?.validate() ?? false) {
                          settingsBloc.setApiUrl(controller.text);
                        }
                      },
                      child: const Text('Save Valid URL'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Tap the button to trigger validation
      await tester.tap(find.text('Save Valid URL'));
      await tester.pump();

      // The URL should have changed because validation passed
      expect(settingsBloc.apiUrl, validUrl);
      
      controller.dispose();
    });
  });
}
