import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';

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
