import 'package:ble_app/models/track_data.dart';
import 'package:isar/isar.dart';

part 'geolocation_data.g.dart';

@Collection()
class GeolocationData {
  Id id = Isar.autoIncrement;

  late double latitude;
  late double longitude;
  late double speed;
  late DateTime timestamp;

  final track = IsarLink<TrackData>();
}
