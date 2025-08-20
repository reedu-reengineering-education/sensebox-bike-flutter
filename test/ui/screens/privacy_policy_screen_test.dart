import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/ui/screens/privacy_policy_screen.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../../test_helpers.dart';
import '../../mocks.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockHttpClient;
  const htmlContent = '''
    <html>
      <body>
        <div class="container-fluid">Privacy Policy Content</div>
      </body>
    </html>
  ''';


  setUp(() {
    initializeTestDependencies();
    mockHttpClient = MockHttpClient();
  });

  group('PrivacyPolicyScreen Tests', () {
    testWidgets('displays loading indicator while fetching privacy policy',
        (WidgetTester tester) async {
      when(() => mockHttpClient.get(Uri.parse(senseBoxBikePrivacyPolicyUrl)))
          .thenAnswer((_) async => http.Response(htmlContent, 200));

      await tester.pumpWidget(createLocalizedTestApp(
        child: const PrivacyPolicyScreen(),
        locale: const Locale('en'),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Verify the title of the page
      expect(find.text('Privacy Policy'), findsOneWidget);

      // Verify the checkbox is displayed and unchecked by default
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);
      expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);

      // Verify the button with text "Proceed" is displayed and disabled
      final proceedButtonFinder = find.widgetWithText(FilledButton, 'Proceed');
      expect(proceedButtonFinder, findsOneWidget);
      expect(tester.widget<FilledButton>(proceedButtonFinder).enabled, isFalse);
    });

    // TBD: write more tests for the PrivacyPolicyScreen
    // with inspiration from https://github.com/flutter/flutter/issues/117422
  });
}