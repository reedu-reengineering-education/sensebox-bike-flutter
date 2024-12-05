import 'dart:math';

import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:isar/isar.dart';
import 'package:sensebox_bike/utils/geo_utils.dart';
import 'package:simplify/simplify.dart';

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
    // tolerance based on number of geolocations
    final tolerance = 0.0001 * pow(geolocations.length / 1000, 2);

    // simplify the polyline
    final points = geolocations
        .map(
            (geolocation) => Point(geolocation.latitude, geolocation.longitude))
        .toList();
    final simplifiedGeolocations =
        simplify(points, tolerance: tolerance, highestQuality: true);

    print(
        'Original: ${geolocations.length} Simplified: ${simplifiedGeolocations.length}');

    final List<List<num>> coordinates = simplifiedGeolocations.map((point) {
      return [point.x, point.y];
    }).toList();

    return encodePolyline(coordinates);
  }
}
