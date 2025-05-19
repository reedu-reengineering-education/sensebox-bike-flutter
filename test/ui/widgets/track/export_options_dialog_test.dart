import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/track/export_options_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/circular_list_tile.dart';

import '../../../test_helpers.dart';

Widget buildDialog({required Future<void> Function(String) onExport}) {
  return createLocalizedTestApp(
    child: Builder(
      builder: (context) => ExportOptionsDialog(onExport: onExport),
    ),
    locale: const Locale('en'),
  );
}

void main() {
  setUpAll(() {
    initializeTestDependencies();
  });

  testWidgets('shows options and disables export button if nothing selected', (tester) async {
    await tester.pumpWidget(buildDialog(onExport: (_) async {}));

    expect(find.text('Regular CSV'), findsOneWidget);
    expect(find.text('openSenseMap CSV'), findsOneWidget);

    // Export button should be disabled initially
    final exportButton = find.widgetWithText(ButtonWithLoader, 'Export');
    final buttonWidget = tester.widget<ButtonWithLoader>(exportButton);

    expect(buttonWidget.onPressed, isNull);
  });

  testWidgets('enables export button when option is selected and calls onExport', (tester) async {
    bool exportCalled = false;
    String? selectedFormat;

    await tester.pumpWidget(buildDialog(
      onExport: (format) async {
        exportCalled = true;
        selectedFormat = format;
      },
    ));

    await tapElement(find.widgetWithText(CircularListTile, 'Regular CSV'), tester);

    final exportButton = find.widgetWithText(ButtonWithLoader, 'Export');
    final buttonWidget = tester.widget<ButtonWithLoader>(exportButton);

    expect(buttonWidget.onPressed, isNotNull);

    await tapElement(exportButton, tester);

    expect(exportCalled, isTrue);
    expect(selectedFormat, 'regular');
  });

  testWidgets('shows error dialog if onExport throws', (tester) async {
    await tester.pumpWidget(buildDialog(
      onExport: (_) async {
        throw Exception('Export failed!');
      },
    ));

    await tapElement(find.widgetWithText(CircularListTile, 'Regular CSV'), tester);
    await tapElement(find.widgetWithText(ButtonWithLoader, 'Export'), tester);

    expect(find.textContaining('Export failed!'), findsOneWidget);
    expect(find.text('Ok'), findsOneWidget);
  });
}