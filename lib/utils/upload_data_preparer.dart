import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

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