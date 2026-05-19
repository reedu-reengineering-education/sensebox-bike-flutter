import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/common/app_dialog.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() {
    initializeTestDependencies();
    disableProviderDebugChecks();
  });

  testWidgets('shows info dialog with icon title and message', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showAppDialog(
                  context: context,
                  title: 'Upload not available',
                  message: 'Please log in first.',
                  type: AppDialogType.info,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.text('Upload not available'), findsOneWidget);
    expect(find.text('Please log in first.'), findsOneWidget);
    expect(find.text('Ok'), findsOneWidget);
  });

  testWidgets('shows confirmation dialog with cancel and confirm actions',
      (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showAppDialog(
                  context: context,
                  title: 'Delete track',
                  message: 'Are you sure?',
                  type: AppDialogType.destructiveConfirmation,
                  cancelLabel: 'Cancel',
                  confirmLabel: 'Delete',
                  confirmIsDestructive: true,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
