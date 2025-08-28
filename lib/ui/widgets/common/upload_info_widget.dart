import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';

/// A widget that displays important upload information to the user.
///
/// This widget shows a consistent info box with:
/// - Warning not to close the app during upload
/// - Information about upload time depending on track length
/// - Instructions for uploading later if needed
class UploadInfoWidget extends StatelessWidget {
  const UploadInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: theme.colorScheme.info.withOpacity(0.2),
        borderRadius: BorderRadius.circular(borderRadiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info,
            color: theme.colorScheme.info,
            size: circleSize,
          ),
          const SizedBox(width: spacing / 2),
          Expanded(
            child: Text(
              localizations.uploadProgressInfo,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
