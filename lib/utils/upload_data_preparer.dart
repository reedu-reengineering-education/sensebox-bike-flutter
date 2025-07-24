import 'package:flutter/widgets.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:flutter/foundation.dart';

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

  /// Static method to group sensor data by geolocation time ranges and return aggregated data
  /// This can be used by sensors without needing a full UploadDataPreparer instance
  static Map<GeolocationData, Map<String, List<double>>>
      groupAndAggregateSensorDataStatic(
      List<Map<String, dynamic>> sensorBuffer, List<GeolocationData> gpsBuffer) {
    final Map<GeolocationData, Map<String, List<double>>> result = {};

    if (sensorBuffer.isEmpty || gpsBuffer.isEmpty) return result;

    // Sort geolocations by timestamp
    final sortedGeolocations = List<GeolocationData>.from(gpsBuffer)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Sort sensor readings by timestamp
    final sortedSensorReadings = List<Map<String, dynamic>>.from(sensorBuffer)
      ..sort((a, b) =>
          (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));

    // Process each geolocation in order
    for (int i = 0; i < sortedGeolocations.length; i++) {
      final GeolocationData currentGeolocation = sortedGeolocations[i];
      final DateTime currentGeolocationTime = currentGeolocation.timestamp;

      // Determine the time range for this geolocation
      DateTime? startTime;
      DateTime? endTime;

      if (i == 0) {
        // First geolocation: get all sensor data before or equal to this geolocation
        startTime = null; // No lower bound
        endTime = currentGeolocationTime;
      } else if (i == sortedGeolocations.length - 1) {
        // Last geolocation: get all remaining sensor data
        final previousGeolocationTime = sortedGeolocations[i - 1].timestamp;
        startTime = previousGeolocationTime;
        endTime = null; // No upper bound
      } else {
        // Middle geolocation: get sensor data between previous and current geolocation
        final previousGeolocationTime = sortedGeolocations[i - 1].timestamp;
        startTime = previousGeolocationTime;
        endTime = currentGeolocationTime;
      }

      // Find sensor readings for this geolocation's time range
      final List<Map<String, dynamic>> readingsForThisGeolocation = [];

      for (final reading in sortedSensorReadings) {
        final DateTime readingTime = reading['timestamp'] as DateTime;

        // Check if reading is in the time range for this geolocation
        bool isInRange = true;
        if (startTime != null && readingTime.isBefore(startTime)) {
          isInRange = false;
        }
        if (endTime != null && readingTime.isAfter(endTime)) {
          isInRange = false;
        }

        if (isInRange) {
          readingsForThisGeolocation.add(reading);
        }
      }

      // Process the sensor readings for this geolocation
      if (readingsForThisGeolocation.isNotEmpty) {
        // Group readings by sensor type
        final Map<String, List<Map<String, dynamic>>> readingsBySensorType = {};

        for (final reading in readingsForThisGeolocation) {
          final String sensorTitle = reading['sensor'] as String;
          readingsBySensorType.putIfAbsent(sensorTitle, () => []).add(reading);
        }

        // Process each sensor type for this geolocation
        for (final entry in readingsBySensorType.entries) {
          final String sensorTitle = entry.key;
          final List<Map<String, dynamic>> readings = entry.value;

          // Extract the sensor data arrays and filter out NaN values
          final List<List<double>> sensorArrays = readings
              .map((reading) => reading['data'] as List<double>)
              .where((array) =>
                  array.isNotEmpty && !array.any((value) => value.isNaN))
              .toList();

          // For static method, we'll use a simple mean aggregation
          // The actual sensor's aggregateData method will be called later
          if (sensorArrays.isNotEmpty) {
            final aggregatedValues =
                _aggregateSensorDataStatic(sensorArrays, sensorTitle);

            // Store the aggregated values for this sensor type and geolocation
            result.putIfAbsent(currentGeolocation, () => {});
            result[currentGeolocation]![sensorTitle] = aggregatedValues;
          }
        }
      }
    }

    return result;
  }

  /// Static aggregation method for use by sensors
  static List<double> _aggregateSensorDataStatic(
      List<List<double>> completeArrays, String sensorTitle) {
    if (completeArrays.isEmpty) return [];

    // Use the same aggregation logic as the actual sensors
    switch (sensorTitle.toLowerCase()) {
      case 'temperature':
      case 'humidity':
      case 'surface_anomaly':
        // Mean aggregation for single-value sensors
        final values = completeArrays
            .map((array) => array.isNotEmpty ? array[0] : 0.0)
            .toList();
        final sum = values.reduce((a, b) => a + b);
        return [sum / values.length];

      case 'finedust':
        // Mean aggregation for multi-value sensors (PM1, PM2.5, PM4, PM10)
        final List<double> sumValues = [0.0, 0.0, 0.0, 0.0];
        int count = completeArrays.length;

        for (var values in completeArrays) {
          for (int i = 0; i < values.length && i < 4; i++) {
            sumValues[i] += values[i];
          }
        }

        return sumValues.map((value) => value / count).toList();

      case 'surface_classification':
        // Mean aggregation for multi-value sensors (asphalt, compacted, paving, sett, standing)
        final List<double> sumValues = [0.0, 0.0, 0.0, 0.0, 0.0];
        int count = completeArrays.length;

        for (var values in completeArrays) {
          for (int i = 0; i < values.length && i < 5; i++) {
            sumValues[i] += values[i];
          }
        }

        return sumValues.map((value) => value / count).toList();

      case 'acceleration':
        // Mean aggregation for multi-value sensors (x, y, z)
        final List<double> sumValues = [0.0, 0.0, 0.0];
        int count = completeArrays.length;

        for (var values in completeArrays) {
          for (int i = 0; i < values.length && i < 3; i++) {
            sumValues[i] += values[i];
          }
        }

        return sumValues.map((value) => value / count).toList();

      case 'distance':
        // Min aggregation for distance sensor
        final values = completeArrays
            .map((array) => array.isNotEmpty ? array[0] : double.infinity)
            .toList();
        return [values.reduce((a, b) => a < b ? a : b)];

      case 'overtaking':
        // Max aggregation for overtaking sensor
        final values = completeArrays
            .map((array) => array.isNotEmpty ? array[0] : 0.0)
            .toList();
        return [values.reduce((a, b) => a > b ? a : b)];

      default:
        // Default to mean aggregation
        final values = completeArrays
            .map((array) => array.isNotEmpty ? array[0] : 0.0)
            .toList();
        final sum = values.reduce((a, b) => a + b);
        return [sum / values.length];
    }
  }

  /// Groups sensor data by geolocation time ranges and returns aggregated data
  /// This method can be used by both sensor._flushBuffers and prepareDataFromBuffers
  Map<GeolocationData, Map<String, List<double>>> groupAndAggregateSensorData(
      List<Map<String, dynamic>> sensorBuffer,
      List<GeolocationData> gpsBuffer) {
    return groupAndAggregateSensorDataStatic(sensorBuffer, gpsBuffer);
  }

  Map<String, dynamic> prepareDataFromBuffers(
      List<Map<String, dynamic>> sensorBuffer,
      List<GeolocationData> gpsBuffer) {
    final Map<String, dynamic> data = {};

    if (gpsBuffer.isEmpty) return data;

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

    // If no sensor data, return only speed data
    if (sensorBuffer.isEmpty) return data;

    // Use the shared grouping and aggregation logic
    final groupedData = groupAndAggregateSensorData(sensorBuffer, gpsBuffer);

    // Convert grouped data to API format
    for (final entry in groupedData.entries) {
      final GeolocationData geolocation = entry.key;
      final Map<String, List<double>> sensorData = entry.value;

      for (final sensorEntry in sensorData.entries) {
        final String sensorTitle = sensorEntry.key;
        final List<double> aggregatedValues = sensorEntry.value;

        String? sensorTitleForMatching =
            getTitleFromSensorKey(sensorTitle, null);
        if (sensorTitleForMatching == null) continue;

        Sensor? sensor = getMatchingSensor(sensorTitleForMatching);
        if (sensor == null) continue;

        // Create one entry per sensor attribute
        final numAttributes = _getSensorArraySize(sensorTitle);
        if (numAttributes > 1) {
          // Multi-value sensor (like finedust, surface_classification)
          for (int j = 0;
              j < numAttributes && j < aggregatedValues.length;
              j++) {
            final attrKey = '_${_getSensorAttributeName(sensorTitle, j)}';
            data['${sensor.id}${attrKey}_${geolocation.timestamp.toIso8601String()}'] =
                {
              'sensor': sensor.id,
              'value': aggregatedValues[j].toStringAsFixed(2),
              'createdAt': geolocation.timestamp.toUtc().toIso8601String(),
              'location': {
                'lat': geolocation.latitude,
                'lng': geolocation.longitude,
              }
            };
          }
        } else {
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

  /// Convert grouped data to API format without doing grouping again
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

        // Handle multi-value sensors directly
        if (sensorTitle == 'surface_classification' ||
            sensorTitle == 'finedust' ||
            sensorTitle == 'acceleration') {
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
          } else if (sensorTitle == 'acceleration') {
            // Find all acceleration sensors
            individualSensors = senseBox.sensors!
                .where((s) => s.title!.toLowerCase().contains('acceleration'))
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
          // Handle single-value sensors using the existing logic
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

  /// Aggregate sensor data using the appropriate aggregation method based on sensor type
  List<double> _aggregateSensorData(
      List<List<double>> completeArrays, String sensorTitle) {
    if (completeArrays.isEmpty) return [];

    // Use the same aggregation logic as the actual sensors
    switch (sensorTitle.toLowerCase()) {
      case 'temperature':
      case 'humidity':
      case 'surface_anomaly':
        // Mean aggregation for single-value sensors
        final values = completeArrays
            .map((array) => array.isNotEmpty ? array[0] : 0.0)
            .toList();
        final sum = values.reduce((a, b) => a + b);
        return [sum / values.length];

      case 'finedust':
        // Mean aggregation for multi-value sensors (PM1, PM2.5, PM4, PM10)
        final List<double> sumValues = [0.0, 0.0, 0.0, 0.0];
        int count = completeArrays.length;

        for (var values in completeArrays) {
          for (int i = 0; i < values.length && i < 4; i++) {
            sumValues[i] += values[i];
          }
        }

        return sumValues.map((value) => value / count).toList();

      case 'surface_classification':
        // Mean aggregation for multi-value sensors (asphalt, compacted, paving, sett, standing)
        final List<double> sumValues = [0.0, 0.0, 0.0, 0.0, 0.0];
        int count = completeArrays.length;

        for (var values in completeArrays) {
          for (int i = 0; i < values.length && i < 5; i++) {
            sumValues[i] += values[i];
          }
        }

        return sumValues.map((value) => value / count).toList();

      case 'acceleration':
        // Mean aggregation for multi-value sensors (x, y, z)
        final List<double> sumValues = [0.0, 0.0, 0.0];
        int count = completeArrays.length;

        for (var values in completeArrays) {
          for (int i = 0; i < values.length && i < 3; i++) {
            sumValues[i] += values[i];
          }
        }

        return sumValues.map((value) => value / count).toList();

      case 'distance':
        // Min aggregation for distance sensor
        final values = completeArrays
            .map((array) => array.isNotEmpty ? array[0] : double.infinity)
            .toList();
        return [values.reduce((a, b) => a < b ? a : b)];

      case 'overtaking':
        // Max aggregation for overtaking sensor
        final values = completeArrays
            .map((array) => array.isNotEmpty ? array[0] : 0.0)
            .toList();
        return [values.reduce((a, b) => a > b ? a : b)];

      default:
        // Default to mean aggregation
        final values = completeArrays
            .map((array) => array.isNotEmpty ? array[0] : 0.0)
            .toList();
        final sum = values.reduce((a, b) => a + b);
        return [sum / values.length];
    }
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

  /// Get the number of attributes for a given sensor title.
  int _getSensorArraySize(String sensorTitle) {
    switch (sensorTitle.toLowerCase()) {
      case 'finedust':
        return 4; // PM1, PM2.5, PM4, PM10
      case 'surface_classification':
        return 5; // Asphalt, Compacted, Paving, Sett, Standing
      case 'acceleration':
        return 3; // x, y, z
      default:
        return 1; // Single-value sensors
    }
  }

  /// Get the attribute name for a given sensor title and index.
  String _getSensorAttributeName(String sensorTitle, int index) {
    switch (sensorTitle.toLowerCase()) {
      case 'finedust':
        switch (index) {
          case 0:
            return 'PM1';
          case 1:
            return 'PM2.5';
          case 2:
            return 'PM4';
          case 3:
            return 'PM10';
        }
        break;
      case 'surface_classification':
        switch (index) {
          case 0:
            return 'Asphalt';
          case 1:
            return 'Compacted';
          case 2:
            return 'Paving';
          case 3:
            return 'Sett';
          case 4:
            return 'Standing';
        }
        break;
      case 'acceleration':
        switch (index) {
          case 0:
            return 'x';
          case 1:
            return 'y';
          case 2:
            return 'z';
        }
        break;
    }
    return ''; // Fallback for unknown sensors or attributes
  }
} 