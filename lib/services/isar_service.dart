// File: lib/services/isar_service.dart
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';

class IsarService {
  final TrackService trackService = TrackService();
  final GeolocationService geolocationService = GeolocationService();
  final SensorService sensorService = SensorService();

  // Additional high-level methods that require coordination between services
}
