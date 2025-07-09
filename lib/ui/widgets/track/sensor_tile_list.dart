import 'package:flutter/material.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
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

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: sensorTitles.length,
      itemBuilder: (context, index) {
        String title = sensorTitles[index]['title']!;
        String? attribute = sensorTitles[index]['attribute'];
        String displayTitle = getTranslatedTitleFromSensorKey(
                title, attribute, context) ??
            title;

        return Card.filled(
          clipBehavior: Clip.hardEdge,
          color: selectedSensorType ==
                  '$title${attribute == null ? '' : '_$attribute'}'
              ? getSensorColor(title).withOpacity(0.25)
              : Theme.of(context).canvasColor,
          child: InkWell(
            onTap: () => onSensorTypeSelected(
                '$title${attribute == null ? '' : '_$attribute'}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Column(
                children: [
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: getSensorColor(title).withOpacity(0.1),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      getSensorIcon(title),
                      size: 24,
                      color: getSensorColor(title),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      displayTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: getSensorColor(title),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
