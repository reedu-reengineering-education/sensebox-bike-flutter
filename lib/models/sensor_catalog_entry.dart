import 'package:sensebox_bike/utils/json_validation.dart';

class SensorCatalogEntry {
  final String label;
  final String key;
  final String? attribute;
  final String? title;
  final String? characteristicUuid;
  final String icon;
  final String unit;
  final String sensorType;

  SensorCatalogEntry({
    required this.label,
    required this.key,
    this.attribute,
    this.title,
    this.characteristicUuid,
    required this.icon,
    required this.unit,
    required this.sensorType,
  });

  String get uploadTitle => title ?? label;

  factory SensorCatalogEntry.fromJson(Map<String, dynamic> json) {
    return SensorCatalogEntry(
      label: requireString(json, 'label', 'SensorCatalogEntry'),
      key: requireString(json, 'key', 'SensorCatalogEntry'),
      attribute: optionalString(json, 'attribute'),
      title: optionalString(json, 'title'),
      characteristicUuid: optionalString(json, 'characteristicUuid'),
      icon: requireString(json, 'icon', 'SensorCatalogEntry'),
      unit: requireString(json, 'unit', 'SensorCatalogEntry'),
      sensorType: requireString(json, 'sensorType', 'SensorCatalogEntry'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'key': key,
      if (attribute != null) 'attribute': attribute,
      if (title != null) 'title': title,
      if (characteristicUuid != null) 'characteristicUuid': characteristicUuid,
      'icon': icon,
      'unit': unit,
      'sensorType': sensorType,
    };
  }

  bool matchesSensorData({
    required String dataKey,
    String? dataAttribute,
    String? dataCharacteristicUuid,
  }) {
    if (key != dataKey) return false;
    if (attribute != dataAttribute) return false;
    if (characteristicUuid != null &&
        dataCharacteristicUuid != null &&
        characteristicUuid != dataCharacteristicUuid) {
      return false;
    }
    return true;
  }
}
