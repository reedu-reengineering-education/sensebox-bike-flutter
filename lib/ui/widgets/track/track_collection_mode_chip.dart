import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/utils/data_collection_mode_ui.dart';

class TrackCollectionModeChip extends StatelessWidget {
  final TrackData track;

  const TrackCollectionModeChip({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final display = collectionModeDisplay(track, localizations);
    if (display == null) {
      return const SizedBox.shrink();
    }

    final color = theme.colorScheme.onSurfaceVariant;

    return Tooltip(
      message: display.text,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: spacing / 2,
          vertical: padding / 2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(display.icon, size: iconSize, color: color),
            const SizedBox(width: spacing / 4),
            Text(
              display.text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
