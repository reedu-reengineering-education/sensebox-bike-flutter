import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/selectable_list_tile.dart';

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
                    setState(() => isExporting = true);
                    try {
                      await widget.onExport(selectedFormat!);
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => isExporting = false);
                        await showCustomDialog(
                            context: context, message: e.toString());
                      }
                    } finally {
                      if (mounted) setState(() => isExporting = false);
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
