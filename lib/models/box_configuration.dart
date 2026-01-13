import 'package:sensebox_bike/utils/json_validation.dart';

class BoxConfiguration {
  final String id;
  final String displayName;
  final String defaultGrouptag;
  final List<SensorDefinition> sensors;

  BoxConfiguration({
    required this.id,
    required this.displayName,
    required this.defaultGrouptag,
    required this.sensors,
  });

  factory BoxConfiguration.fromJson(Map<String, dynamic> json) {
    return BoxConfiguration(
      id: requireString(json, 'id', 'BoxConfiguration'),
      displayName: requireString(json, 'displayName', 'BoxConfiguration'),
      defaultGrouptag: requireString(json, 'defaultGrouptag', 'BoxConfiguration'),
      sensors: requireList<SensorDefinition>(
        json,
        'sensors',
        'BoxConfiguration',
        (item) => SensorDefinition.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  List<Map<String, dynamic>> get sensorsAsMap {
    return sensors.map((sensor) => sensor.toMap()).toList();
  }
}

class SensorDefinition {
  final String id;
  final String icon;
  final String title;
  final String unit;
  final String sensorType;

  SensorDefinition({
    required this.id,
    required this.icon,
    required this.title,
    required this.unit,
    required this.sensorType,
  });

  factory SensorDefinition.fromJson(Map<String, dynamic> json) {
    return SensorDefinition(
      id: requireString(json, 'id', 'SensorDefinition'),
      icon: requireString(json, 'icon', 'SensorDefinition'),
      title: requireString(json, 'title', 'SensorDefinition'),
      unit: requireString(json, 'unit', 'SensorDefinition'),
      sensorType: requireString(json, 'sensorType', 'SensorDefinition'),
    );
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

