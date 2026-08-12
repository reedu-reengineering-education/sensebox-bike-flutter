import 'package:flutter/material.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/track/sensor_tile.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

class SensorTileList extends StatelessWidget {
  final List<SensorData> sensorData;
  final String selectedSensorType;
  final ValueChanged<String> onSensorTypeSelected;

  const SensorTileList({
    super.key,
    required this.sensorData,
    required this.selectedSensorType,
    required this.onSensorTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sensorEntries = getUniqueSortedSensorEntries(sensorData);
    final filteredEntries = _filterSensorEntries(sensorEntries);
    final tiles = _buildSensorTiles(context, filteredEntries);

    return SizedBox(
      height: 200,
      child: _SensorTileGrid(tileList: tiles),
    );
  }

  List<SensorEntry> _filterSensorEntries(List<SensorEntry> entries) {
    if (FeatureFlags.hideSurfaceAnomalySensor) {
      return entries
          .where((entry) => entry.title != 'surface_anomaly')
          .toList();
    }
    return entries;
  }

  List<Widget> _buildSensorTiles(
      BuildContext context, List<SensorEntry> entries) {
    return entries.map((entry) {
      final sensorKey = entry.title;
      final attribute = entry.attribute;
      final displayTitle =
          getTranslatedTitleFromSensorKey(sensorKey, attribute, context) ??
              sensorKey;
      final sensorTypeKey =
          '$sensorKey${attribute == null ? '' : '_$attribute'}';
      final colorScheme = Theme.of(context).colorScheme;
      final cardColor = selectedSensorType == sensorTypeKey
          ? Color.alphaBlend(
              getSensorColor(sensorKey).withValues(alpha: 0.24),
              colorScheme.surfaceContainerHigh,
            )
          : colorScheme.surfaceContainerHigh;

      return SensorTile(
        title: displayTitle,
        cardColor: cardColor,
        sensorColor: getSensorColor(sensorKey),
        sensorIcon: getSensorIcon(sensorKey),
        isSelected: selectedSensorType == sensorTypeKey,
        onTap: () => onSensorTypeSelected(sensorTypeKey),
      );
    }).toList();
  }
}

class _SensorTileGrid extends StatefulWidget {
  final List<Widget> tileList;
  const _SensorTileGrid({required this.tileList});

  @override
  State<_SensorTileGrid> createState() => _SensorTileGridState();
}

class _SensorTileGridState extends State<_SensorTileGrid> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // On the smaller screens, we want to show 3 tiles per row
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 400 ? 3 : 4;

    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: GridView.count(
        controller: _controller,
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.all(spacing / 2),
        crossAxisCount: crossAxisCount,
        children: widget.tileList,
      ),
    );
  }
}
