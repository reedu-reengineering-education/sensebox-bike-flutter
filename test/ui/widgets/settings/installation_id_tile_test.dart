import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/services/installation_id_service.dart';
import 'package:sensebox_bike/ui/widgets/settings/installation_id_tile.dart';

import '../../../test_helpers.dart';

void main() {
  setUpAll(() {
    initializeTestDependencies();
    InstallationIdService.setIdForTesting('abcd-1234-ef56');
  });

  Widget buildTestWidget() {
    return createLocalizedTestApp(
      locale: const Locale('en'),
      child: const Scaffold(body: InstallationIdTile()),
    );
  }

  testWidgets('shows the stored installation ID', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Installation ID'), findsOneWidget);
    expect(find.text('abcd-1234-ef56'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });

  testWidgets('copies the installation ID on tap', (tester) async {
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

    await tester.tap(find.text('Installation ID'));
    await tester.pumpAndSettle();

    expect(copiedText, 'abcd-1234-ef56');
    expect(find.text('Installation ID copied to clipboard'), findsOneWidget);
  });
}
