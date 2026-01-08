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
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      defaultGrouptag: json['defaultGrouptag'] as String,
      sensors: (json['sensors'] as List<dynamic>)
          .map((sensor) => SensorDefinition.fromJson(sensor as Map<String, dynamic>))
          .toList(),
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
      id: json['id'] as String,
      icon: json['icon'] as String,
      title: json['title'] as String,
      unit: json['unit'] as String,
      sensorType: json['sensorType'] as String,
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

