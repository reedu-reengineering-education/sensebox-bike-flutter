import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

/// Utility class for preparing data for upload to OpenSenseMap
class UploadDataPreparer {
  final SenseBox senseBox;

  UploadDataPreparer({required this.senseBox});

  /// Prepare data for upload from GeolocationData list (used by LiveUploadService)
  Map<String, dynamic> prepareDataFromGeolocationData(
      List<GeolocationData> geoDataToUpload) {
    Map<String, dynamic> data = {};

    for (var geoData in geoDataToUpload) {
      for (var sensorData in geoData.sensorData) {
        String? sensorTitle =
            getTitleFromSensorKey(sensorData.title, sensorData.attribute);

        if (sensorTitle == null) {
          continue;
        }

        Sensor? sensor = getMatchingSensor(sensorTitle);

        // Skip if sensor is not found
        if (sensor == null || sensorData.value.isNaN) {
          continue;
        }

        data[sensor.id! + geoData.timestamp.toIso8601String()] = {
          'sensor': sensor.id,
          'value': sensorData.value.toStringAsFixed(2),
          'createdAt': geoData.timestamp.toUtc().toIso8601String(),
          'location': {
            'lat': geoData.latitude,
            'lng': geoData.longitude,
          }
        };
      }

      String speedSensorId = getSpeedSensorId();

      data['speed_${geoData.timestamp.toIso8601String()}'] = {
        'sensor': speedSensorId,
        'value': geoData.speed.toStringAsFixed(2),
        'createdAt': geoData.timestamp.toUtc().toIso8601String(),
        'location': {
          'lat': geoData.latitude,
          'lng': geoData.longitude,
        }
      };
    }

    return data;
  }

  Map<String, dynamic> prepareDataFromBuffers(
      List<Map<String, dynamic>> sensorBuffer, List<GeolocationData> gpsBuffer) {
    final Map<String, dynamic> data = {};

    // Group sensor readings by geolocation and sensor type for aggregation
    final Map<GeolocationData, Map<String, List<Map<String, dynamic>>>>
        readingsByGeolocation = {};

    for (final sensorEntry in List.from(sensorBuffer)) {
      final DateTime sensorTs = sensorEntry['timestamp'] as DateTime;
      final double value = sensorEntry['value'] as double;
      final String sensorTitle = sensorEntry['sensor'] as String;
      final String? attribute = sensorEntry['attribute'] as String?;

      // Find the latest GPS with gps.timestamp <= sensorTs
      GeolocationData? gps = List.from(gpsBuffer)
          .where((g) =>
              g.timestamp.isBefore(sensorTs) ||
              g.timestamp.isAtSameMomentAs(sensorTs))
          .fold<GeolocationData?>(
              null,
              (prev, g) => prev == null || g.timestamp.isAfter(prev.timestamp)
                  ? g
                  : prev);

      if (gps == null) {
        continue;
      }

      String? sensorTitleForMatching =
          getTitleFromSensorKey(sensorTitle, attribute);
      if (sensorTitleForMatching == null) {
        continue;
      }

      Sensor? sensor = getMatchingSensor(sensorTitleForMatching);
      if (sensor == null || value.isNaN) {
        continue;
      }

      // Create a unique key for each sensor type (title + attribute)
      String sensorKey =
          attribute != null ? '${sensorTitle}_$attribute' : sensorTitle;

      // Group by geolocation and sensor type
      readingsByGeolocation.putIfAbsent(gps, () => {});
      readingsByGeolocation[gps]!.putIfAbsent(sensorKey, () => []);
      readingsByGeolocation[gps]![sensorKey]!.add({
        'sensor': sensor,
        'value': value,
        'timestamp': sensorTs,
        'attribute': attribute,
      });
    }

    // Aggregate sensor data per geolocation and create one entry per sensor type
    for (final entry in readingsByGeolocation.entries) {
      final GeolocationData gps = entry.key;
      final Map<String, List<Map<String, dynamic>>> sensorReadings =
          entry.value;

      for (final sensorKey in sensorReadings.keys) {
        final List<Map<String, dynamic>> readings = sensorReadings[sensorKey]!;
        final Sensor sensor = readings.first['sensor'] as Sensor;
        final String? attribute = readings.first['attribute'] as String?;

        // Aggregate the values for this sensor type
        final List<double> values =
            readings.map((r) => r['value'] as double).toList();
        final double aggregatedValue = _aggregateValues(values, sensor);

        // Create one entry per sensor type per geolocation
        final attrKey = attribute != null ? '_$attribute' : '';
        data['${sensor.id}${attrKey}_${gps.timestamp.toIso8601String()}'] = {
          'sensor': sensor.id,
          'value': aggregatedValue.toStringAsFixed(2),
          'createdAt': gps.timestamp.toUtc().toIso8601String(),
          'location': {
            'lat': gps.latitude,
            'lng': gps.longitude,
          }
        };
      }
    }

    // Add speed data from ALL GPS points (one per geolocation)
    if (gpsBuffer.isNotEmpty) {
      String speedSensorId = getSpeedSensorId();
      for (final gps in gpsBuffer) {
        data['speed_${gps.timestamp.toIso8601String()}'] = {
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

    return data;
  }

  /// Aggregate sensor values using the sensor's aggregation method
  double _aggregateValues(List<double> values, Sensor sensor) {
    if (values.isEmpty) return 0.0;
    if (values.length == 1) return values.first;

    // For now, use mean aggregation (this could be made configurable per sensor type)
    // In the future, we could call sensor.aggregateData() if we had access to the sensor instance
    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  /// Get matching sensor from senseBox
  Sensor? getMatchingSensor(String sensorTitle) {
    return senseBox.sensors!
        .where((sensor) =>
            sensor.title!.toLowerCase() == sensorTitle.toLowerCase())
        .firstOrNull;
  }

  /// Get speed sensor ID from senseBox
  String getSpeedSensorId() {
    return senseBox.sensors!
        .firstWhere((sensor) => sensor.title == 'Speed')
        .id!;
  }
} 