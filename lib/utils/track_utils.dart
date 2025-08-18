import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

double getMinSensorValue(List<GeolocationData> data, String sensorType) {
  double minVal = double.infinity;
  for (GeolocationData data in data) {
    for (SensorData sensor in data.sensorData) {
      if ('${sensor.title}${sensor.attribute == null ? '' : '_${sensor.attribute}'}' ==
          sensorType) {
        minVal = min(minVal, sensor.value);
      }
    }
  }
  return minVal;
}

double getMaxSensorValue(List<GeolocationData> data, String sensorType) {
  double maxVal = double.negativeInfinity;
  for (GeolocationData data in data) {
    for (SensorData sensor in data.sensorData) {
      if ('${sensor.title}${sensor.attribute == null ? '' : '_${sensor.attribute}'}' ==
          sensorType) {
        maxVal = max(maxVal, sensor.value);
      }
    }
  }
  return maxVal;
}

CoordinateBounds calculateBounds(List<GeolocationData> geolocations,
    {double minDelta = 0.002}) {
  if (geolocations.isEmpty) {
    // Default to world bounds if empty
    return CoordinateBounds(
      southwest: Point(coordinates: Position(-180, -90)),
      northeast: Point(coordinates: Position(180, 90)),
      infiniteBounds: true,
    );
  }

  GeolocationData south = geolocations.first;
  GeolocationData west = geolocations.first;
  GeolocationData north = geolocations.first;
  GeolocationData east = geolocations.first;

  for (GeolocationData data in geolocations) {
    if (data.latitude < south.latitude) south = data;
    if (data.latitude > north.latitude) north = data;
    if (data.longitude < west.longitude) west = data;
    if (data.longitude > east.longitude) east = data;
  }

  double latDelta = (north.latitude - south.latitude).abs();
  double lonDelta = (east.longitude - west.longitude).abs();

  double minLat = south.latitude;
  double maxLat = north.latitude;
  double minLon = west.longitude;
  double maxLon = east.longitude;

  if (latDelta < minDelta) {
    minLat -= (minDelta - latDelta) / 2;
    maxLat += (minDelta - latDelta) / 2;
  }
  if (lonDelta < minDelta) {
    minLon -= (minDelta - lonDelta) / 2;
    maxLon += (minDelta - lonDelta) / 2;
  }

  return CoordinateBounds(
    southwest: Point(coordinates: Position(minLon, minLat)),
    northeast: Point(coordinates: Position(maxLon, maxLat)),
    infiniteBounds: true,
  );
}

Color sensorColorForValue({
  required double value,
  required double min,
  required double max,
  bool allowGray = true,
}) {
  if (allowGray && min == 0.0 && max == 0.0) {
    return Colors.grey;
  }

  if (value <= min) {
    return Colors.green;
  } else if (value >= max) {
    return Colors.red;
  } else {
    final mid = min + (max - min) * 0.5;
    if (value <= mid) {
      final t = (value - min) / (mid - min);
      return Color.lerp(Colors.green, Colors.orange, t)!;
    } else {
      final t = (value - mid) / (max - mid);
      return Color.lerp(Colors.orange, Colors.red, t)!;
    }
  }
}

List<String> order = [
  'temperature',
  'humidity',
  'distance',
  'overtaking',
  'surface_classification_asphalt',
  'surface_classification_compacted',
  'surface_classification_paving',
  'surface_classification_sett',
  'surface_classification_standing',
  'surface_anomaly',
  'acceleration_x',
  'acceleration_y',
  'acceleration_z',
  'finedust_pm1',
  'finedust_pm2.5',
  'finedust_pm4',
  'finedust_pm10',
  'gps_latitude',
  'gps_longitude',
  'gps_speed',
];

List<Map<String, String?>> buildSensorTiles(List<SensorData> sensorData) {
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
    int indexA = order.indexOf(
        '${a['title']}${a['attribute'] == null ? '' : '_${a['attribute']}'}');
    int indexB = order.indexOf(
        '${b['title']}${b['attribute'] == null ? '' : '_${b['attribute']}'}');
    return indexA.compareTo(indexB);
  });

  return sensorTitles;
}

String trackName(TrackData track, {String errorMessage = "No data available"}) {
  if (track.geolocations.isEmpty) {
    return errorMessage;
  }

  String trackStart =
      DateFormat('dd-MM-yyyy HH:mm').format(track.geolocations.first.timestamp);
  String trackEnd =
      DateFormat('HH:mm').format(track.geolocations.last.timestamp);

  return '$trackStart - $trackEnd';
}

/// Extracts all unique sensor data from a list of geolocations.
/// This function collects sensor data from all geolocations in a track,
/// ensuring that all sensors available on the box during recording are represented.
List<SensorData> getAllUniqueSensorData(List<GeolocationData> geolocations) {
  final allSensorData = <SensorData>{};
  for (final geolocation in geolocations) {
    allSensorData.addAll(geolocation.sensorData);
  }
  return allSensorData.toList();
}

/// Utility class for preparing data for upload to OpenSenseMap
class UploadDataPreparer {
  final SenseBox senseBox;

  UploadDataPreparer({required this.senseBox});

  Map<String, dynamic> prepareDataFromGroupedData(
      Map<GeolocationData, Map<String, List<double>>> groupedData,
      List<GeolocationData> gpsBuffer) {
    final Map<String, dynamic> data = {};

    if (gpsBuffer.isEmpty) {
      return data;
    }

    // Add speed data from ALL GPS points (one per geolocation) - always include this
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

    // Convert grouped data to API format
    for (final entry in groupedData.entries) {
      final GeolocationData geolocation = entry.key;
      final Map<String, List<double>> sensorData = entry.value;

      for (final sensorEntry in sensorData.entries) {
        final String sensorTitle = sensorEntry.key;
        final List<double> aggregatedValues = sensorEntry.value;

        if (sensorTitle == "gps") {
          continue;
        }

        // Handle multi-value sensors directly
        if (sensorTitle == 'surface_classification' ||
            sensorTitle == 'finedust' ||
            sensorTitle == 'distance' ||
            sensorTitle == 'overtaking' ||
            sensorTitle == 'surface_anomaly') {
          // For multi-value sensors, we need to find all the individual sensors
          List<Sensor> individualSensors = [];

          if (sensorTitle == 'finedust') {
            // Find all finedust sensors
            individualSensors = senseBox.sensors!
                .where((s) => s.title!.toLowerCase().contains('finedust'))
                .toList();
          } else if (sensorTitle == 'surface_classification') {
            // Find all surface classification sensors (including "Standing")
            individualSensors = senseBox.sensors!
                .where((s) =>
                    s.title!.toLowerCase().contains('surface') ||
                    s.title!.toLowerCase() == 'standing')
                .toList();
          } else if (sensorTitle == 'distance') {
            // Find the Overtaking Distance sensor
            individualSensors = senseBox.sensors!
                .where((s) =>
                    s.title!.toLowerCase().contains('overtaking distance'))
                .toList();
          } else if (sensorTitle == 'overtaking') {
            // Find the Overtaking Manoeuvre sensor
            individualSensors = senseBox.sensors!
                .where((s) =>
                    s.title!.toLowerCase().contains('overtaking manoeuvre'))
                .toList();
          } else if (sensorTitle == 'surface_anomaly') {
            // Find the Surface Anomaly sensor
            individualSensors = senseBox.sensors!
                .where(
                    (s) => s.title!.toLowerCase().contains('surface anomaly'))
                .toList();
          }

          // Create entries for each individual sensor
          for (int j = 0;
              j < aggregatedValues.length && j < individualSensors.length;
              j++) {
            final individualSensor = individualSensors[j];
            data['${individualSensor.id}_${geolocation.timestamp.toIso8601String()}'] =
                {
              'sensor': individualSensor.id,
              'value': aggregatedValues[j].toStringAsFixed(2),
              'createdAt': geolocation.timestamp.toUtc().toIso8601String(),
              'location': {
                'lat': geolocation.latitude,
                'lng': geolocation.longitude,
              }
            };
          }
        } else {
          String? sensorTitleForMatching =
              getTitleFromSensorKey(sensorTitle, null);
          if (sensorTitleForMatching == null) {
            continue;
          }

          Sensor? sensor = getMatchingSensor(sensorTitleForMatching);
          if (sensor == null) {
            continue;
          }

          // Single-value sensor (like temperature, humidity)
          data['${sensor.id}_${geolocation.timestamp.toIso8601String()}'] = {
            'sensor': sensor.id,
            'value': aggregatedValues.isNotEmpty
                ? aggregatedValues[0].toStringAsFixed(2)
                : '0.00',
            'createdAt': geolocation.timestamp.toUtc().toIso8601String(),
            'location': {
              'lat': geolocation.latitude,
              'lng': geolocation.longitude,
            }
          };
        }
      }
    }

    return data;
  }

  Sensor? getMatchingSensor(String sensorTitle) {
    return senseBox.sensors!
        .where((sensor) =>
            sensor.title!.toLowerCase() == sensorTitle.toLowerCase())
        .firstOrNull;
  }

  String getSpeedSensorId() {
    return senseBox.sensors!
        .firstWhere((sensor) => sensor.title == 'Speed')
        .id!;
  }
}
