import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:isar/isar.dart';
import 'package:sensebox_bike/utils/geo_utils.dart';

part 'track_data.g.dart';

@Collection()
class TrackData {
  Id id = Isar.autoIncrement;

  @Backlink(to: "track")
  final geolocations = IsarLinks<GeolocationData>();

  @ignore
  Duration get duration => Duration(
      milliseconds: geolocations.isNotEmpty
          ? geolocations.last.timestamp.millisecondsSinceEpoch -
              geolocations.first.timestamp.millisecondsSinceEpoch
          : 0);

  @ignore
  double get distance {
    return getDistance(geolocations.toList());
  }

  @ignore
  String get encodedPolyline {
    final List<List<num>> coordinates = geolocations
        .map((geolocation) => [geolocation.latitude, geolocation.longitude])
        .toList();

    return encodePolyline(coordinates);
  }
}
