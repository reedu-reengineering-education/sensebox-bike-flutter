import 'package:flutter/material.dart';
import 'package:sensebox_bike/constants.dart';
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
    List<Map<String, String?>> sensorTitles = sensorData
        .map((e) => {'title': e.title, 'attribute': e.attribute})
        .map((map) => map.entries.map((e) => '${e.key}:${e.value}').join(','))
        .toSet()
        .map((str) {
      var entries = str.split(',').map((e) => e.split(':'));
      return Map<String, String?>.fromEntries(
        entries.map((e) => MapEntry(e[0], e[1] == 'null' ? null : e[1])),
      );
    }).toList();

    // Filter out surface_anomaly if the feature flag is enabled
    if (FeatureFlags.hideSurfaceAnomalySensor) {
      sensorTitles.removeWhere((sensor) => sensor['title'] == 'surface_anomaly');
    }

    sensorTitles.sort((a, b) {
      int indexA = sensorOrder.indexOf(
          '${a['title']}${a['attribute'] == null ? '' : '_${a['attribute']}'}');
      int indexB = sensorOrder.indexOf(
          '${b['title']}${b['attribute'] == null ? '' : '_${b['attribute']}'}');
      return indexA.compareTo(indexB);
    });
    final tileList = <Widget>[];
    for (var sensor in sensorTitles) {
      String title = sensor['title']!;
      String? attribute = sensor['attribute'];
      String displayTitle =
          getTranslatedTitleFromSensorKey(title, attribute, context) ?? title;
      Color cardColor = selectedSensorType ==
              '$title${attribute == null ? '' : '_$attribute'}'
          ? getSensorColor(title).withOpacity(0.25)
          : Theme.of(context).canvasColor;

      tileList.add(SensorTile(
        title: displayTitle,
        cardColor: cardColor,
        sensorColor: getSensorColor(title),
        sensorIcon: getSensorIcon(title),
        onTap: () => onSensorTypeSelected(
            '$title${attribute == null ? '' : '_$attribute'}'),
      ));
    }

    return SizedBox(
      height: 200,
      child: _SensorTileGrid(tileList: tileList),
    );
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
