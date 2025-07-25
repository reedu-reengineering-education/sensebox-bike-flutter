import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/sensors/gps_sensor.dart';

String? getSearchKey(String key, String? attribute) {
  if (attribute != null) {
    return '${key}_${attribute.replaceAll(".", "_")}';
  }

  return key;
}

String? getTitleFromSensorKey(String key, String? attribute) {
  String searchKey = getSearchKey(key, attribute) ?? key;

  switch (searchKey) {
    case 'temperature':
      return 'Temperature';
    case 'humidity':
      return 'Rel. Humidity';
    case 'finedust_pm10':
      return 'Finedust PM10';
    case 'finedust_pm4':
      return 'Finedust PM4';
    case 'finedust_pm2_5':
      return 'Finedust PM2.5';
    case 'finedust_pm1':
      return 'Finedust PM1';
    case 'distance':
      return 'Overtaking Distance';
    case 'overtaking':
      return 'Overtaking Manoeuvre';
    case 'surface_classification_asphalt':
      return 'Surface Asphalt';
    case 'surface_classification_sett':
      return 'Surface Sett';
    case 'surface_classification_compacted':
      return 'Surface Compacted';
    case 'surface_classification_paving':
      return 'Surface Paving';
    case 'surface_classification_standing':
      return 'Standing';
    case 'surface_anomaly':
      return 'Surface Anomaly';
    case 'speed':
      return 'Speed';
    case 'acceleration_x':
      return 'Acceleration X';
    case 'acceleration_y':
      return 'Acceleration Y';
    case 'acceleration_z':
      return 'Acceleration Z';
    case 'gps_latitude':
      return 'GPS Latitude';
    case 'gps_longitude':
      return 'GPS Longitude';
    case 'gps_speed':
      return 'Speed';
    default:
      debugPrint("Unknown sensor key: $searchKey");
      return null;
  }
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
      return AppLocalizations.of(context)!.sensorGPSLat;
    case 'gps_longitude':
      return AppLocalizations.of(context)!.sensorGPSLong;
    case 'gps_speed':
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
      return Icons.sensors;
    case 'acceleration':
      return Icons.vibration;
    case 'finedust':
      return Icons.grain;
    case 'gps':
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

String? findSensorIdByData(SensorData sensorData, List<Sensor> boxSensors) {
  final sensorDataTitle =
      getTitleFromSensorKey(sensorData.title, sensorData.attribute);

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
  // Return null if no match is found
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
  // Don't store NaN or infinite values
  if (sensorData.value.isNaN || sensorData.value.isInfinite) {
    return false;
  }

  // Don't store zero GPS coordinates (invalid GPS data)
  if (sensorData.title == 'gps' &&
      (sensorData.attribute == 'latitude' ||
          sensorData.attribute == 'longitude') &&
      sensorData.value == 0.0) {
    return false;
  }

  return true;
}
