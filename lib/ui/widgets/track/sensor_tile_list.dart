import 'package:flutter/material.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/layout/form_factor.dart';
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
    final crossAxisCount =
        context.trackSensorCrossAxisCount(tileCount: tiles.length);
    final height = _gridHeight(context, crossAxisCount);

    return SizedBox(
      height: height,
      child: _SensorTileGrid(
        tileList: tiles,
        crossAxisCount: crossAxisCount,
      ),
    );
  }

  double _gridHeight(BuildContext context, int crossAxisCount) {
    // Phone keeps the existing fixed height.
    if (!context.isTablet) return 200;

    // One row of square tiles (default GridView aspect ratio 1).
    final width = MediaQuery.sizeOf(context).width;
    const padding = spacing / 2;
    final tileExtent = (width - padding * 2) / crossAxisCount;
    return padding * 2 + tileExtent;
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
      final cardColor = selectedSensorType == sensorTypeKey
          ? getSensorColor(sensorKey).withOpacity(0.25)
          : Theme.of(context).canvasColor;

      return SensorTile(
        title: displayTitle,
        cardColor: cardColor,
        sensorColor: getSensorColor(sensorKey),
        sensorIcon: getSensorIcon(sensorKey),
        onTap: () => onSensorTypeSelected(sensorTypeKey),
      );
    }).toList();
  }
}

class _SensorTileGrid extends StatefulWidget {
  final List<Widget> tileList;
  final int crossAxisCount;

  const _SensorTileGrid({
    required this.tileList,
    required this.crossAxisCount,
  });

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
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: GridView.count(
        controller: _controller,
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.all(spacing / 2),
        crossAxisCount: widget.crossAxisCount,
        children: widget.tileList,
      ),
    );
  }
}
