import 'package:flutter/material.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/sensebox.dart' as sensebox_model;
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/sensors/gps_sensor.dart';
import 'package:sensebox_bike/sensors/distance_sensor.dart';
import 'package:sensebox_bike/sensors/distance_right_sensor.dart';
import 'package:sensebox_bike/sensors/overtaking_prediction_sensor.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import 'package:sensebox_bike/sensors/humidity_sensor.dart';
import 'package:sensebox_bike/sensors/acceleration_sensor.dart';
import 'package:sensebox_bike/sensors/surface_classification_sensor.dart';
import 'package:sensebox_bike/sensors/surface_anomaly_sensor.dart';
import 'package:sensebox_bike/sensors/finedust_sensor.dart';
import 'package:sensebox_bike/services/sensor_catalog_registry.dart';

String buildCanonicalSensorKey(String title, String? attribute) {
  return '${title}${attribute == null ? '' : '_${attribute}'}';
}

String getCanonicalKeyFromApiTitle(String apiTitle) {
  final titleLower = apiTitle.toLowerCase();

  if (titleLower.contains('asphalt')) {
    return 'surface_classification_asphalt';
  } else if (titleLower.contains('compacted')) {
    return 'surface_classification_compacted';
  } else if (titleLower.contains('paving')) {
    return 'surface_classification_paving';
  } else if (titleLower.contains('sett')) {
    return 'surface_classification_sett';
  } else if (titleLower == 'standing') {
    return 'surface_classification_standing';
  }

  return '';
}

int compareSensorKeysByCanonicalOrder(String sensorKeyA, String sensorKeyB) {
  final indexA = sensorOrder.indexOf(sensorKeyA);
  final indexB = sensorOrder.indexOf(sensorKeyB);

  if (indexA != -1 && indexB != -1) {
    return indexA.compareTo(indexB);
  }

  if (indexA != -1) return -1;
  if (indexB != -1) return 1;

  return sensorKeyA.compareTo(sensorKeyB);
}

int compareSensorsByCanonicalOrder(
  String titleA,
  String? attributeA,
  String titleB,
  String? attributeB,
) {
  final keyA = buildCanonicalSensorKey(titleA, attributeA);
  final keyB = buildCanonicalSensorKey(titleB, attributeB);
  return compareSensorKeysByCanonicalOrder(keyA, keyB);
}

int _compareApiSensorsByCanonicalOrder(
  String apiTitleA,
  String apiTitleB,
) {
  final keyA = getCanonicalKeyFromApiTitle(apiTitleA);
  final keyB = getCanonicalKeyFromApiTitle(apiTitleB);
  
  final canonicalComparison = compareSensorKeysByCanonicalOrder(keyA, keyB);
  if (canonicalComparison != 0) {
    return canonicalComparison;
  }
  
  return apiTitleA.compareTo(apiTitleB);
}

List<sensebox_model.Sensor> sortApiSensorsByCanonicalOrder(List<sensebox_model.Sensor> sensors) {
  final sorted = List<sensebox_model.Sensor>.from(sensors);
  sorted.sort((a, b) =>
      _compareApiSensorsByCanonicalOrder(a.title ?? '', b.title ?? ''));
  return sorted;
}

List<Map<String, String?>> sortSensorTilesByCanonicalOrder(
    List<Map<String, String?>> tiles) {
  final sorted = List<Map<String, String?>>.from(tiles);
  sorted.sort((a, b) {
    final keyA = buildCanonicalSensorKey(a['title'] ?? '', a['attribute']);
    final keyB = buildCanonicalSensorKey(b['title'] ?? '', b['attribute']);
    
    final canonicalComparison = compareSensorKeysByCanonicalOrder(keyA, keyB);
    if (canonicalComparison != 0) {
      return canonicalComparison;
    }
    
    return keyA.compareTo(keyB);
  });
  return sorted;
}

String? getSearchKey(String key, String? attribute) {
  if (attribute != null) {
    return '${key}_${attribute.replaceAll(".", "_")}';
  }

  return key;
}

String? getTitleFromSensorKey(String key, String? attribute) {
  return SensorCatalogRegistry.getUploadTitle(
    key,
    attribute,
    characteristicUuid: null,
  );
}

String? getTranslatedTitleFromSensorKey(
    String key, String? attribute, BuildContext context) {
  String searchKey = getSearchKey(key, attribute) ?? key;

  switch (searchKey) {
    case 'temperature':
      return AppLocalizations.of(context)!.sensorTemperature;
    case 'humidity':
      return AppLocalizations.of(context)!.sensorHumidity;
    case 'finedust_pm10':
      return AppLocalizations.of(context)!.sensorFinedustPM10;
    case 'finedust_pm4':
      return AppLocalizations.of(context)!.sensorFinedustPM4;
    case 'finedust_pm2_5':
      return AppLocalizations.of(context)!.sensorFinedustPM25;
    case 'finedust_pm1':
      return AppLocalizations.of(context)!.sensorFinedustPM1;
    case 'distance':
      return AppLocalizations.of(context)!.sensorDistance;
    case 'distance_right':
      return AppLocalizations.of(context)!.sensorDistanceRight;
    case 'overtaking':
      return AppLocalizations.of(context)!.sensorOvertaking;
    case 'surface_classification_asphalt':
      return AppLocalizations.of(context)!.sensorSurfaceAsphalt;
    case 'surface_classification_sett':
      return AppLocalizations.of(context)!.sensorSurfaceSett;
    case 'surface_classification_compacted':
      return AppLocalizations.of(context)!.sensorSurfaceCompacted;
    case 'surface_classification_paving':
      return AppLocalizations.of(context)!.sensorSurfacePaving;
    case 'surface_classification_standing':
      return AppLocalizations.of(context)!.sensorSurfaceStanding;
    case 'surface_anomaly':
      return AppLocalizations.of(context)!.sensorSurfaceAnomaly;
    case 'speed':
      return AppLocalizations.of(context)!.sensorSpeed;
    case 'acceleration_x':
      return AppLocalizations.of(context)!.sensorAccelerationX;
    case 'acceleration_y':
      return AppLocalizations.of(context)!.sensorAccelerationY;
    case 'acceleration_z':
      return AppLocalizations.of(context)!.sensorAccelerationZ;
    case 'gps_latitude':
    case 'sensor_gps_latitude':
      return AppLocalizations.of(context)!.sensorGPSLat;
    case 'gps_longitude':
    case 'sensor_gps_longitude':
      return AppLocalizations.of(context)!.sensorGPSLong;
    case 'gps_speed':
    case 'sensor_gps_speed':
      return AppLocalizations.of(context)!.sensorSpeed;
    default:
      debugPrint("Unknown sensor key: $searchKey");
      return null;
  }
}

IconData getSensorIcon(String sensorType) {
  switch (sensorType) {
    case 'temperature':
      return Icons.thermostat_outlined;
    case 'humidity':
      return Icons.water_drop_outlined;
    case 'distance':
      return Icons.arrow_back;
    case 'distance_right':
      return Icons.arrow_forward;
    case 'acceleration':
      return Icons.vibration;
    case 'finedust':
      return Icons.grain;
    case 'gps':
    case 'sensor_gps':
      return Icons.gps_off;
    case 'overtaking':
      return Icons.directions_car;
    case 'surface_anomaly':
      return Icons.swap_horiz;
    case 'surface_classification':
      return Icons.water;
    default:
      return Icons.sensors;
  }
}

Color getSensorColor(String sensorType) {
  switch (sensorType) {
    case 'temperature':
      return Colors.redAccent;
    case 'humidity':
      return Colors.blueAccent;
    case 'distance':
      return Colors.deepPurpleAccent;
    case 'acceleration':
      return Colors.greenAccent;
    case 'finedust':
      return Colors.blueGrey;
    case 'gps':
    case 'sensor_gps':
      return Colors.blue;
    case 'overtaking':
      return Colors.teal;
    case 'surface_anomaly':
      return Colors.yellow.shade700;
    case 'surface_classification':
      return Colors.brown;
    default:
      return Colors.grey;
  }
}

String? findSensorIdByData(
    SensorData sensorData, List<sensebox_model.Sensor> boxSensors) {
  for (final boxSensor in boxSensors) {
    final catalogEntry =
        SensorCatalogRegistry.findByUploadTitle(boxSensor.title ?? '');
    if (catalogEntry != null &&
        catalogEntry.matchesSensorData(
          dataKey: sensorData.title,
          dataAttribute: sensorData.attribute,
          dataCharacteristicUuid: sensorData.characteristicUuid,
        )) {
      return boxSensor.id;
    }
  }

  final sensorDataTitle = SensorCatalogRegistry.getUploadTitle(
    sensorData.title,
    sensorData.attribute,
    characteristicUuid: sensorData.characteristicUuid,
  );

  if (sensorDataTitle == null) {
    debugPrint(
        "No matching title found for sensor key: ${sensorData.title} with attribute: ${sensorData.attribute}");
    return null;
  }

  for (var sensor in boxSensors) {
    if (sensorDataTitle == sensor.title) {
      return sensor.id;
    }
  }
  return null;
}

SensorData createGpsSpeedSensorData(GeolocationData geoData) {
  return SensorData()
    ..title = 'gps'
    ..attribute = 'speed'
    ..value = geoData.speed
    ..characteristicUuid = GPSSensor.sensorCharacteristicUuid
    ..geolocationData.value = geoData;
}

bool shouldStoreSensorData(SensorData sensorData) {
  if (sensorData.value.isNaN || sensorData.value.isInfinite) {
    return false;
  }

  if ((sensorData.title == 'distance' ||
          sensorData.title == 'distance_right') &&
      sensorData.value == 0.0) {
    return false;
  }

  if (sensorData.title == 'gps' &&
      (sensorData.attribute == 'latitude' ||
          sensorData.attribute == 'longitude') &&
      sensorData.value == 0.0) {
    return false;
  }

  return true;
}

String? findSpeedSensorId(sensebox_model.SenseBox senseBox) {
  final sensors = senseBox.sensors;
  if (sensors == null || sensors.isEmpty) {
    return null;
  }

  final speedSensor = sensors
      .where((sensor) => (sensor.title ?? '').toLowerCase() == 'speed')
      .firstOrNull;
  if (speedSensor != null) {
    return speedSensor.id;
  }

  return sensors
      .where((sensor) => (sensor.title ?? '').toLowerCase().contains('speed'))
      .firstOrNull
      ?.id;
}

void addSpeedEntries({
  required Map<String, dynamic> target,
  required List<GeolocationData> gpsBuffer,
  required String speedSensorId,
}) {
  for (final gps in gpsBuffer) {
    target['speed_${gps.timestamp.toIso8601String()}'] = {
      'sensor': speedSensorId,
      'value': gps.speed.toStringAsFixed(2),
      'createdAt': gps.timestamp.toUtc().toIso8601String(),
      'location': {
        'lat': gps.latitude,
        'lng': gps.longitude,
      }
    };
  }
}

int getUiPriorityByUuid(String characteristicUuid) {
  final uuidToPriority = {
    DistanceSensor.sensorCharacteristicUuid: DistanceSensor.staticUiPriority,
    DistanceRightSensor.sensorCharacteristicUuid:
        DistanceRightSensor.staticUiPriority,
    OvertakingPredictionSensor.sensorCharacteristicUuid:
        OvertakingPredictionSensor.staticUiPriority,
    TemperatureSensor.sensorCharacteristicUuid:
        TemperatureSensor.staticUiPriority,
    HumiditySensor.sensorCharacteristicUuid: HumiditySensor.staticUiPriority,
    AccelerationSensor.sensorCharacteristicUuid:
        AccelerationSensor.staticUiPriority,
    GPSSensor.sensorCharacteristicUuid: GPSSensor.staticUiPriority,
    SurfaceClassificationSensor.sensorCharacteristicUuid:
        SurfaceClassificationSensor.staticUiPriority,
    SurfaceAnomalySensor.sensorCharacteristicUuid:
        SurfaceAnomalySensor.staticUiPriority,
    FinedustSensor.sensorCharacteristicUuid: FinedustSensor.staticUiPriority,
  };

  return uuidToPriority[characteristicUuid] ?? 999999;
}

class SensorEntry {
  final String title;
  final String? attribute;
  final String characteristicUuid;

  SensorEntry({
    required this.title,
    required this.attribute,
    required this.characteristicUuid,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorEntry &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          attribute == other.attribute &&
          characteristicUuid == other.characteristicUuid;

  @override
  int get hashCode =>
      title.hashCode ^ attribute.hashCode ^ characteristicUuid.hashCode;
}

List<SensorEntry> getUniqueSortedSensorEntries(List<SensorData> sensorData) {
  final uniqueEntries = <SensorEntry>{};
  for (final data in sensorData) {
    uniqueEntries.add(SensorEntry(
      title: data.title,
      attribute: data.attribute,
      characteristicUuid: data.characteristicUuid,
    ));
  }

  final entriesList = uniqueEntries.toList();
  entriesList.sort((a, b) {
    // Speed (gps with attribute 'speed') should always be last
    final isSpeedA = a.title == 'gps' && a.attribute == 'speed';
    final isSpeedB = b.title == 'gps' && b.attribute == 'speed';
    
    if (isSpeedA && !isSpeedB) return 1; // Speed goes after everything
    if (!isSpeedA && isSpeedB) return -1; // Non-speed goes before speed
    if (isSpeedA && isSpeedB) return 0; // Both are speed, keep order
    
    // For non-speed entries, sort by priority first
    final priorityA = getUiPriorityByUuid(a.characteristicUuid);
    final priorityB = getUiPriorityByUuid(b.characteristicUuid);
    final priorityComparison = priorityA.compareTo(priorityB);
    
    if (priorityComparison != 0) {
      return priorityComparison;
    }
    
    final canonicalComparison = compareSensorsByCanonicalOrder(
      a.title,
      a.attribute,
      b.title,
      b.attribute,
    );
    if (canonicalComparison != 0) {
      return canonicalComparison;
    }
    
    return 0;
  });

  return entriesList;
}

