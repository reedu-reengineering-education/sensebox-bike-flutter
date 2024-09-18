import 'dart:math';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';

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
