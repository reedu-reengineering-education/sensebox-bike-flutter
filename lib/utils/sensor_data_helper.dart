import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';

/// Helper class for sensor data transformation and formatting
/// Extracted from upload_data_preparer.dart to be reused across the app
class SensorDataHelper {
  static SensorData createGpsSpeedSensorData(GeolocationData geoData) {
    return SensorData()
      ..title = 'gps'
      ..attribute = 'speed'
      ..value = geoData.speed
      ..characteristicUuid = 'gps_speed_from_geolocation'
      ..geolocationData.value = geoData;
  }

  static bool shouldStoreSensorData(SensorData sensorData) {
    // Don't store NaN or infinite values
    if (sensorData.value.isNaN || sensorData.value.isInfinite) {
      return false;
    }
    
    // Don't store zero GPS coordinates (invalid GPS data)
    if (sensorData.title == 'gps' && 
        (sensorData.attribute == 'latitude' || sensorData.attribute == 'longitude') &&
        sensorData.value == 0.0) {
      return false;
    }
    
    return true;
  }
} 