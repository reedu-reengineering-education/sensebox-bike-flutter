import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/sensor_catalog_entry.dart';
import 'package:sensebox_bike/services/sensor_catalog_registry.dart';
import 'package:sensebox_bike/utils/json_validation.dart';

class BoxConfiguration {
  final String id;
  final String displayName;
  final String defaultGrouptag;
  final List<SensorDefinition> sensors;
  final DataCollectionMode dataCollectionMode;
  final int collectionIntervalSeconds;

  BoxConfiguration({
    required this.id,
    required this.displayName,
    required this.defaultGrouptag,
    required this.sensors,
    this.dataCollectionMode = DataCollectionMode.postRide,
    this.collectionIntervalSeconds = defaultCollectionIntervalSeconds,
  });

  factory BoxConfiguration.fromJson(Map<String, dynamic> json) {
    final sensorsJson = requireList<dynamic>(
      json,
      'sensors',
      'BoxConfiguration',
      (item) => item,
    );

    final dataCollectionMode = DataCollectionMode.fromJson(
      optionalString(json, 'dataCollectionMode'),
    );
    final collectionIntervalSeconds = parseCollectionIntervalSeconds(
      json['collectionIntervalSeconds'],
    );

    return BoxConfiguration(
      id: requireString(json, 'id', 'BoxConfiguration'),
      displayName: requireString(json, 'displayName', 'BoxConfiguration'),
      defaultGrouptag: requireString(json, 'defaultGrouptag', 'BoxConfiguration'),
      sensors: sensorsJson.asMap().entries.map((entry) {
        return SensorDefinition.fromJsonRef(
          entry.value as Map<String, dynamic>,
          fallbackId: entry.key.toString(),
        );
      }).toList(),
      dataCollectionMode: dataCollectionMode,
      collectionIntervalSeconds: collectionIntervalSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'defaultGrouptag': defaultGrouptag,
      if (dataCollectionMode != DataCollectionMode.postRide)
        'dataCollectionMode': dataCollectionMode.toJson(),
      if (dataCollectionMode == DataCollectionMode.periodic &&
          collectionIntervalSeconds != defaultCollectionIntervalSeconds)
        'collectionIntervalSeconds': collectionIntervalSeconds,
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
