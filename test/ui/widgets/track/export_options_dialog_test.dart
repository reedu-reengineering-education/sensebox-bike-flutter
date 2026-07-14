import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/track/export_options_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/selectable_list_tile.dart';

import '../../../test_helpers.dart';

class _DialogHost extends StatefulWidget {
  const _DialogHost({required this.onExport});

  final Future<void> Function(String) onExport;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => ExportOptionsDialog(onExport: widget.onExport),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget buildDialog({required Future<void> Function(String) onExport}) {
  return createLocalizedTestApp(
    child: Scaffold(
      body: _DialogHost(onExport: onExport),
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
    await tester.pumpAndSettle();

    expect(find.text('Standard CSV'), findsOneWidget);
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
    await tester.pumpAndSettle();

    await tapElement(
        find.widgetWithText(SelectableListTile, 'Standard CSV'), tester);

    final exportButton = find.widgetWithText(ButtonWithLoader, 'Export');
    final buttonWidget = tester.widget<ButtonWithLoader>(exportButton);

    expect(buttonWidget.onPressed, isNotNull);

    await tapElement(exportButton, tester);

    expect(exportCalled, isTrue);
    expect(selectedFormat, 'regular');
  });

  testWidgets('shows snackbar if onExport throws', (tester) async {
    await tester.pumpWidget(buildDialog(
      onExport: (_) async {
        throw Exception('Export failed!');
      },
    ));
    await tester.pumpAndSettle();

    await tapElement(
        find.widgetWithText(SelectableListTile, 'Standard CSV'), tester);
    await tapElement(find.widgetWithText(ButtonWithLoader, 'Export'), tester);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}