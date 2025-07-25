import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/sensors/gps_sensor.dart';

class SensorDataHelper {
  static SensorData createGpsSpeedSensorData(GeolocationData geoData) {
    return SensorData()
      ..title = 'gps'
      ..attribute = 'speed' 
      ..value = geoData.speed
      ..characteristicUuid = GPSSensor.sensorCharacteristicUuid
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