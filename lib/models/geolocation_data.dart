import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:isar_community/isar.dart';

part 'geolocation_data.g.dart';

@Collection()
class GeolocationData {
  Id id = Isar.autoIncrement;

  late double latitude;
  late double longitude;
  late double speed;
  late DateTime timestamp;

  final track = IsarLink<TrackData>();

  @Backlink(to: "geolocationData")
  final sensorData = IsarLinks<SensorData>();
}
