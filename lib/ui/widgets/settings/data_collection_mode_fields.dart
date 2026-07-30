import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/ui/widgets/common/selectable_list_tile.dart';
import 'package:sensebox_bike/utils/data_collection_mode_ui.dart';

/// Mode + conditional interval dropdowns for create-box / inline forms.
class DataCollectionModeFields extends StatelessWidget {
  final DataCollectionMode mode;
  final int intervalSeconds;
  final ValueChanged<DataCollectionMode>? onModeChanged;
  final ValueChanged<int>? onIntervalChanged;
  final bool enabled;

  const DataCollectionModeFields({
    super.key,
    required this.mode,
    required this.intervalSeconds,
    this.onModeChanged,
    this.onIntervalChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        DropdownButtonFormField<DataCollectionMode>(
          value: mode,
          decoration: InputDecoration(
            labelText: localizations.settingsDataCollectionMode,
          ),
          items: DataCollectionMode.values
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    dataCollectionModeSettingsLabel(item, localizations),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (selected) {
                  if (selected != null) {
                    onModeChanged?.call(selected);
                  }
                }
              : null,
        ),
        if (mode.usesPeriodicTimer) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: intervalSeconds,
            decoration: InputDecoration(
              labelText: localizations.settingsCollectionInterval,
            ),
            items: collectionIntervalPresetsSeconds
                .map(
                  (seconds) => DropdownMenuItem(
                    value: seconds,
                    child: Text(
                      localizations.trackCollectionModePeriodic(seconds),
                    ),
                  ),
                )
                .toList(),
            onChanged: enabled
                ? (seconds) {
                    if (seconds != null) {
                      onIntervalChanged?.call(seconds);
                    }
                  }
                : null,
          ),
        ],
      ],
    );
  }
}

/// Radio list with descriptions — settings mode dialog content.
class DataCollectionModeRadioList extends StatelessWidget {
  final DataCollectionMode groupValue;
  final ValueChanged<DataCollectionMode> onChanged;

  const DataCollectionModeRadioList({
    super.key,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final mode in DataCollectionMode.values)
          RadioListTile<DataCollectionMode>(
            title: Text(
              dataCollectionModeSettingsLabel(mode, localizations),
            ),
            subtitle: Text(
              dataCollectionModeSettingsDescription(mode, localizations),
              style: subtitleStyle,
            ),
            value: mode,
            groupValue: groupValue,
            onChanged: (selected) {
              if (selected != null) {
                onChanged(selected);
              }
            },
            isThreeLine: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          ),
      ],
    );
  }
}

/// Interval preset tiles — settings interval dialog content.
class CollectionIntervalPresetList extends StatelessWidget {
  final int selectedSeconds;
  final ValueChanged<int> onSelected;

  const CollectionIntervalPresetList({
    super.key,
    required this.selectedSeconds,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final seconds in collectionIntervalPresetsSeconds)
          SelectableListTile(
            title: localizations.trackCollectionModePeriodic(seconds),
            isSelected: selectedSeconds == seconds,
            onTap: () => onSelected(seconds),
          ),
      ],
    );
  }
}
