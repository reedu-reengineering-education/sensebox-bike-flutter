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
    if (isDownloading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: Loader(light: true)),
      );
    }

    return IconButton(
      icon: const Icon(Icons.file_download),
      onPressed: isDisabled
          ? null
          : () async {
              await showDialog(
                context: context,
                builder: (context) => ExportOptionsDialog(
                  onExport: onExport,
                ),
              );
            },
    );
  }
}
