import 'package:sensebox_bike/models/sensor_catalog_entry.dart';
import 'package:sensebox_bike/services/sensor_catalog_registry.dart';
import 'package:sensebox_bike/utils/json_validation.dart';

class BoxConfiguration {
  /// Id (and default grouptag) of a box assembled by the user from the
  /// sensor catalog instead of a predefined template.
  static const String customId = 'custom';

  final String id;
  final String displayName;
  final String defaultGrouptag;
  final List<SensorDefinition> sensors;

  /// Featured models are offered up front when creating a box; the others
  /// are tucked away behind "More models".
  final bool featured;

  BoxConfiguration({
    required this.id,
    required this.displayName,
    required this.defaultGrouptag,
    required this.sensors,
    this.featured = false,
  });

  /// Sensor keys the user can pick for a custom box, in catalog order.
  ///
  /// Selection works per key, not per catalog entry: multi-value sensors
  /// (finedust, surface classification, acceleration) are uploaded by
  /// position, so a box must contain all of their attributes or none.
  static List<String> selectableSensorKeys(List<SensorCatalogEntry> catalog) {
    return catalog.map((entry) => entry.key).toSet().toList(growable: false);
  }

  /// Builds a box containing every catalog entry whose key is in
  /// [sensorKeys].
  ///
  /// The catalog lists `distance` twice (legacy "Overtaking Distance" and
  /// "Distance Left"); the later entry wins so the left sensor is named
  /// consistently with "Distance Right". Upload matching accepts both titles.
  factory BoxConfiguration.custom({
    required List<SensorCatalogEntry> catalog,
    required Set<String> sensorKeys,
    String displayName = 'Custom',
  }) {
    final selected = <String, SensorCatalogEntry>{};
    for (final entry in catalog) {
      if (!sensorKeys.contains(entry.key)) continue;
      selected['${entry.key}|${entry.attribute ?? ''}'] = entry;
    }

    final sensors = selected.values.toList().asMap().entries.map((entry) {
      return SensorDefinition.fromCatalog(
        catalogEntry: entry.value,
        titleOverride: entry.value.title,
        id: entry.key.toString(),
      );
    }).toList();

    return BoxConfiguration(
      id: customId,
      displayName: displayName,
      defaultGrouptag: customId,
      sensors: sensors,
    );
  }

  factory BoxConfiguration.fromJson(Map<String, dynamic> json) {
    final sensorsJson = requireList<dynamic>(
      json,
      'sensors',
      'BoxConfiguration',
      (item) => item,
    );

    return BoxConfiguration(
      id: requireString(json, 'id', 'BoxConfiguration'),
      displayName: requireString(json, 'displayName', 'BoxConfiguration'),
      defaultGrouptag:
          requireString(json, 'defaultGrouptag', 'BoxConfiguration'),
      featured: json['featured'] == true,
      sensors: sensorsJson.asMap().entries.map((entry) {
        return SensorDefinition.fromJsonRef(
          entry.value as Map<String, dynamic>,
          fallbackId: entry.key.toString(),
        );
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'defaultGrouptag': defaultGrouptag,
      if (featured) 'featured': true,
      'sensors': sensors.map((sensor) => sensor.toRefJson()).toList(),
    };
  }

  List<Map<String, dynamic>> get sensorsAsMap {
    return sensors.map((sensor) => sensor.toMap()).toList();
  }
}

class SensorDefinition {
  final String key;
  final String? attribute;
  final String? titleOverride;
  final String id;
  final String icon;
  final String title;
  final String unit;
  final String sensorType;
  final String? characteristicUuid;

  SensorDefinition({
    required this.key,
    this.attribute,
    this.titleOverride,
    required this.id,
    required this.icon,
    required this.title,
    required this.unit,
    required this.sensorType,
    this.characteristicUuid,
  });

  factory SensorDefinition.fromJsonRef(
    Map<String, dynamic> json, {
    required String fallbackId,
  }) {
    final key = requireString(json, 'key', 'SensorDefinition');
    final attribute = optionalString(json, 'attribute');
    final titleOverride = optionalString(json, 'title');

    final catalogEntry = SensorCatalogRegistry.findByKey(
      key,
      attribute: attribute,
      titleOverride: titleOverride,
    );
    if (catalogEntry == null) {
      throw FormatException(
        'SensorDefinition.fromJson: no catalog entry for key="$key"'
        '${attribute != null ? ', attribute="$attribute"' : ''}'
        '${titleOverride != null ? ', title="$titleOverride"' : ''}',
      );
    }

    return SensorDefinition.fromCatalog(
      catalogEntry: catalogEntry,
      titleOverride: titleOverride,
      id: optionalString(json, 'id') ?? fallbackId,
    );
  }

  factory SensorDefinition.fromCatalog({
    required SensorCatalogEntry catalogEntry,
    String? titleOverride,
    String? id,
  }) {
    return SensorDefinition(
      key: catalogEntry.key,
      attribute: catalogEntry.attribute,
      titleOverride: titleOverride,
      id: id ?? catalogEntry.key,
      icon: catalogEntry.icon,
      title: titleOverride ?? catalogEntry.uploadTitle,
      unit: catalogEntry.unit,
      sensorType: catalogEntry.sensorType,
      characteristicUuid: catalogEntry.characteristicUuid,
    );
  }

  Map<String, dynamic> toRefJson() {
    return {
      'key': key,
      if (attribute != null) 'attribute': attribute,
      if (titleOverride != null) 'title': titleOverride,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'icon': icon,
      'title': title,
      'unit': unit,
      'sensorType': sensorType,
    };
  }
}
