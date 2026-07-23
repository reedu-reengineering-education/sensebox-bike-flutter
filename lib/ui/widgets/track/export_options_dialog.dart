import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/selectable_list_tile.dart';
import 'package:sensebox_bike/services/error_service.dart';

class ExportOptionsDialog extends StatefulWidget {
  final Future<void> Function(String selectedFormat) onExport;

  const ExportOptionsDialog({super.key, required this.onExport});

  @override
  State<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog> {
  String? selectedFormat;
  bool isExporting = false;

  Widget _buildActions(BuildContext context, AppLocalizations localizations) {
    return Row(
      children: [
        Expanded(
          child: ButtonWithLoader(
            isLoading: isExporting,
            onPressed: (selectedFormat == null || isExporting)
                ? null
                : () async {
                  final parentScaffoldMessenger =
                    ScaffoldMessenger.maybeOf(context);
                  final errorColor = Theme.of(context).colorScheme.error;
                    final format = selectedFormat;
                    setState(() => isExporting = true);
                    // Pop the dialog first to ensure context is proper for overlay
                    Navigator.of(context).pop();

                    // Then trigger the export after dialog is closed
                    try {
                      await widget.onExport(format!);
                    } catch (e) {
                      ErrorService.handleError(e, StackTrace.current);
                      final message = e.toString().replaceFirst('Exception: ', '');
                      parentScaffoldMessenger?.showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: errorColor,
                        ),
                      );
                    }
                  },
            text: localizations.generalExport,
          ),
        ),
      ],
    );
  }

  Widget _buildOptions(AppLocalizations localizations) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableListTile(
          title: localizations.regularCsv,
          isSelected: selectedFormat == 'regular',
          onTap: () => setState(() => selectedFormat = 'regular'),
        ),
        const CustomSpacer(height: 8),
        SelectableListTile(
          title: localizations.openSenseMapCsv,
          isSelected: selectedFormat == 'openSenseMap',
          onTap: () => setState(() => selectedFormat = 'openSenseMap'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localizations.selectCsvFormat),
      content: _buildOptions(localizations),
      actions: [
        _buildActions(context, localizations),
      ],
    );
  }
}
