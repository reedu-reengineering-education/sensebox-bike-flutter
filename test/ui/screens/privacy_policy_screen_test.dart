import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/screens/privacy_policy_screen.dart';

import '../../fakes/fake_webview_platform.dart';
import '../../test_helpers.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  setUpAll(() {
    initializeTestDependencies();
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  group('PrivacyPolicyScreen', () {
    testWidgets('shows first-run acceptance controls', (tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        child: const PrivacyPolicyScreen(),
        locale: const Locale('en'),
      ));
      await tester.pump();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Proceed'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Proceed'),
        ).enabled,
        isFalse,
      );
    });
  });
}
