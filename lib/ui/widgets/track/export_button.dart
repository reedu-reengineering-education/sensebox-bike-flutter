import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/track/export_options_dialog.dart';

class ExportButton extends StatelessWidget {
  final bool isDownloading;
  final bool isDisabled;
  final Future<void> Function(String selectedFormat) onExport;

  const ExportButton({
    required this.isDownloading,
    required this.isDisabled,
    required this.onExport,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () async {
              await showDialog(
                context: context,
                builder: (context) => ExportOptionsDialog(
                  onExport: onExport,
                ),
              );
            },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        padding: const EdgeInsets.all(12),
        child: Center(
          child: isDownloading
              ? Loader(light: true)
              : Icon(
                  Icons.file_download,
                  size: 24,
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withOpacity(0.38)
                      : theme.colorScheme.onSurface,
                ),
        ),
      ),
    );
  }
}