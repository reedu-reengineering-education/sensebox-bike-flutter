import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/support_id_service.dart';
import 'package:sensebox_bike/ui/widgets/settings/app_info_section.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../test_helpers.dart';

void main() {
  setUpAll(() {
    initializeTestDependencies();
    SupportIdService.setIdForTesting('abcd-1234-ef56');

    PackageInfo.setMockInitialValues(
      appName: 'senseBox Bike',
      packageName: 'de.reedu.senseboxbike',
      version: '3.4.0',
      buildNumber: '340',
      buildSignature: 'test',
    );
  });

  Widget buildTestWidget({
    Future<bool> Function(Uri url, {LaunchMode mode})? launchUrlFunction,
  }) {
    return createLocalizedTestApp(
      locale: const Locale('en'),
      child: Scaffold(
        body: AppInfoSection(
          launchUrlFunction: launchUrlFunction ??
              (Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async =>
                  true,
        ),
      ),
    );
  }

  group('AppInfoSection', () {
    testWidgets('shows version label', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Version: 3.4.0 (340)'), findsOneWidget);
      expect(find.text('Storage used'), findsOneWidget);
    });

    testWidgets('shows the changelog for the current version on tap',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Version: 3.4.0 (340)'));
      await tester.pumpAndSettle();

      expect(find.textContaining("What's new in 3.4.0"), findsOneWidget);
    });

    testWidgets('launches privacy policy URL on tap', (tester) async {
      Uri? launchedUrl;

      await tester.pumpWidget(
        buildTestWidget(
          launchUrlFunction: (url,
              {LaunchMode mode = LaunchMode.platformDefault}) async {
            launchedUrl = url;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(launchedUrl, Uri.parse(senseBoxBikePrivacyPolicyUrl));
    });

    group('support ID', () {
      testWidgets('shows the stored support ID', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Support ID'), findsOneWidget);
        expect(find.text('abcd-1234-ef56'), findsOneWidget);
      });

      testWidgets('copies the support ID on tap', (tester) async {
        String? copiedText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(() => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null));

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Support ID'));
        await tester.pumpAndSettle();

        expect(copiedText, 'abcd-1234-ef56');
        expect(find.text('Support ID copied to clipboard'), findsOneWidget);
      });
    });
  });
}
