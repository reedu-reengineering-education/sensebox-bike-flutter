import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

double getMinSensorValue(List<GeolocationData> data, String sensorType) {
  double minVal = double.infinity;
  for (GeolocationData data in data) {
    for (SensorData sensor in data.sensorData) {
      if (buildCanonicalSensorKey(sensor.title, sensor.attribute) ==
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
      if (buildCanonicalSensorKey(sensor.title, sensor.attribute) ==
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

  if (FeatureFlags.hideSurfaceAnomalySensor) {
    sensorTitles.removeWhere((sensor) => sensor['title'] == 'surface_anomaly');
  }

  return sortSensorTilesByCanonicalOrder(sensorTitles);
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

List<SensorData> getAllUniqueSensorData(List<GeolocationData> geolocations) {
  final allSensorData = <SensorData>{};
  for (final geolocation in geolocations) {
    allSensorData.addAll(geolocation.sensorData);
  }
  return allSensorData.toList();
}

String getFirstAvailableSensorType(List<SensorData> sensorData) {
  const String defaultSensorType = 'distance';

  if (sensorData.isEmpty) return defaultSensorType;

  final availableSensors = sensorData
      .map((sensor) => buildCanonicalSensorKey(sensor.title, sensor.attribute))
      .toSet();

  if (availableSensors.contains(defaultSensorType)) {
    return defaultSensorType;
  }

  for (final sensorType in sensorOrder) {
    if (availableSensors.contains(sensorType)) {
      return sensorType;
    }
  }

  return availableSensors.first;
}

/// Utility class for preparing data for upload to OpenSenseMap
class UploadDataPreparer {
  final SenseBox senseBox;

  UploadDataPreparer({required this.senseBox});

  Map<String, dynamic> prepareDataFromBatches(List<SensorBatch> batches) {
    final groupedData = <GeolocationData, Map<String, List<double>>>{};
    for (final batch in batches) {
      
      // Check if this geoLocation already exists in groupedData
      final alreadyExists = groupedData.containsKey(batch.geoLocation);
      if (alreadyExists) {
      }
      
      groupedData[batch.geoLocation] = batch.aggregatedData;
    }
    return prepareDataFromGroupedData(groupedData, groupedData.keys.toList());
  }

  Map<String, dynamic> prepareDataFromGroupedData(
      Map<GeolocationData, Map<String, List<double>>> groupedData,
      List<GeolocationData> gpsBuffer) {
    final Map<String, dynamic> data = {};

    if (gpsBuffer.isEmpty) {
      return data;
    }

    // Add speed data from ALL GPS points (one per geolocation) - always include this
    final String? speedSensorId = findSpeedSensorId(senseBox);
    if (speedSensorId != null) {
      addSpeedEntries(
        target: data,
        gpsBuffer: gpsBuffer,
        speedSensorId: speedSensorId,
      );
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

        if (FeatureFlags.hideSurfaceAnomalySensor &&
            sensorTitle == 'surface_anomaly') {
          continue;
        }

        // Handle multi-value sensors directly
        if (sensorTitle == 'surface_classification' ||
            sensorTitle == 'finedust' ||
            sensorTitle == 'overtaking' ||
            sensorTitle == 'surface_anomaly' ||
            sensorTitle == 'acceleration') {
          // For multi-value sensors, we need to find all the individual sensors
          List<Sensor> individualSensors = [];
          List<double> orderedValues = aggregatedValues;

          if (sensorTitle == 'finedust') {
            // Find all finedust sensors
            individualSensors = senseBox.sensors!
                .where((s) => s.title!.toLowerCase().contains('finedust'))
                .toList();
          } else if (sensorTitle == 'surface_classification') {
            individualSensors = sortApiSensorsByCanonicalOrder(
              senseBox.sensors!
                  .where((s) =>
                      s.title!.toLowerCase().contains('surface') ||
                      s.title!.toLowerCase() == 'standing')
                  .toList(),
            );
            // Reorder aggregatedValues to match sorted API sensors order
            // Device order: [asphalt, compacted, paving, sett, standing]
            // Canonical order: [asphalt, compacted, paving, sett, standing]
            // They match, but we ensure consistency by mapping via canonical keys
            orderedValues = _reorderSurfaceClassificationValues(
              aggregatedValues, individualSensors);
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
          } else if (sensorTitle == 'acceleration') {
            // Find Acceleration X/Y/Z sensors (classic box)
            individualSensors = senseBox.sensors!
                .where((s) => s.title == 'Acceleration X' || s.title == 'Acceleration Y' || s.title == 'Acceleration Z')
                .toList();
          }

          // Create entries for each individual sensor
          for (int j = 0;
              j < orderedValues.length && j < individualSensors.length;
              j++) {
            final individualSensor = individualSensors[j];
            data['${individualSensor.id}_${geolocation.timestamp.toIso8601String()}'] =
                {
              'sensor': individualSensor.id,
              'value': orderedValues[j].toStringAsFixed(2),
              'createdAt': geolocation.timestamp.toUtc().toIso8601String(),
              'location': {
                'lat': geolocation.latitude,
                'lng': geolocation.longitude,
              }
            };
          }
        } else {
          // Handle single-value sensors, including distance sensors
          Sensor? sensor;

          if (sensorTitle == 'distance') {
            // "distance" can map to "Overtaking Distance" (older boxes) or "Distance Left" (LAUDS)
            sensor = senseBox.sensors!.where((s) {
              final titleLower = s.title!.toLowerCase();
              return titleLower.contains('overtaking distance') ||
                  titleLower == 'distance left';
            }).firstOrNull;
          } else if (sensorTitle == 'distance_right') {
            // "distance_right" maps to "Distance Right" (LAUDS)
            sensor = senseBox.sensors!
                .where((s) => s.title!.toLowerCase() == 'distance right')
                .firstOrNull;
          } else {
            // For other sensors, use the standard title mapping
            String? sensorTitleForMatching =
                getTitleFromSensorKey(sensorTitle, null);
            if (sensorTitleForMatching == null) {
              continue;
            }
            sensor = getMatchingSensor(sensorTitleForMatching);
          }

          if (sensor == null) {
            continue;
          }

          // Single-value sensor (like temperature, humidity, distance)
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

  List<double> _reorderSurfaceClassificationValues(
      List<double> values, List<Sensor> sortedSensors) {
    if (values.length != 5 || sortedSensors.length != 5) {
      return values;
    }

    final reordered = List<double>.filled(5, 0.0);

    for (int i = 0; i < sortedSensors.length; i++) {
      final sensor = sortedSensors[i];
      final apiTitle = (sensor.title ?? '').toLowerCase();
      
      int deviceIndex = -1;
      if (apiTitle.contains('asphalt')) {
        deviceIndex = 0;
      } else if (apiTitle.contains('compacted')) {
        deviceIndex = 1;
      } else if (apiTitle.contains('paving')) {
        deviceIndex = 2;
      } else if (apiTitle.contains('sett')) {
        deviceIndex = 3;
      } else if (apiTitle == 'standing') {
        deviceIndex = 4;
      }

      if (deviceIndex >= 0 && deviceIndex < values.length) {
        reordered[i] = values[deviceIndex];
      }
    }

    return reordered;
  }
}
