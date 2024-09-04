import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:isar/isar.dart';

part 'track_data.g.dart';

@Collection()
class TrackData {
  Id id = Isar.autoIncrement;

  @Backlink(to: "track")
  final geolocations = IsarLinks<GeolocationData>();
}
