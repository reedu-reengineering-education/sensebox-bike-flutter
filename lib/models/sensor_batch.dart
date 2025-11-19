import 'package:sensebox_bike/models/geolocation_data.dart';

/// Represents a batch of sensor data for one GPS point
/// This is the single source of truth for sensor data in memory
class SensorBatch {
  final GeolocationData geoLocation;
  final Map<String, List<double>> aggregatedData;
  final DateTime timestamp;
  bool isUploadPending = false;
  bool isUploaded = false;
  bool isSavedToDb = false;

  SensorBatch({
    required this.geoLocation,
    required this.aggregatedData,
    required this.timestamp,
  });

  /// Get all sensor titles in this batch
  List<String> get sensorTitles => aggregatedData.keys.toList();

  /// Check if batch is empty
  bool get isEmpty => aggregatedData.isEmpty;

  /// Get total number of data points across all sensors
  int get totalDataPoints {
    return aggregatedData.values.fold(0, (sum, list) => sum + list.length);
  }

  @override
  String toString() {
    return 'SensorBatch(geoId: ${geoLocation.id}, sensors: ${aggregatedData.keys}, '
        'uploaded: $isUploaded, pending: $isUploadPending)';
  }
}

