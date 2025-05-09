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

  double calculateTolerance(int numberOfCoordinates) {
    // Base tolerance for small datasets
    const double baseTolerance = 0.00001;
    // Growth factor for exponential scaling
    const double growthFactor = 1.01;

    return baseTolerance * pow(growthFactor, (numberOfCoordinates / 1000));
  }

  @ignore
  String get encodedPolyline {
    // Convert geolocations to a list of Point<double>
    final List<Point<double>> coordinates = geolocations
        .map(
            (geolocation) => Point(geolocation.longitude, geolocation.latitude))
        .toList();

    // Handle the case where there is only one point
    if (coordinates.length == 1) {
      final singlePoint = coordinates.first;
      final repeatedPoints = [
        [singlePoint.x, singlePoint.y],
        [singlePoint.x, singlePoint.y]
      ];
      return encodePolyline(repeatedPoints);
    }
    // tolerance based on number of geolocations
    final tolerance = calculateTolerance(coordinates.length);
    // Simplify the polyline with a tolerance (e.g., 0.0001)
    final simplifiedCoordinates = simplify<Point<double>>(
      coordinates,
      tolerance: tolerance, // Adjust tolerance to control simplification
      highestQuality: false, // Use high-quality simplification
    );
    // Convert simplified points back to a list of lists for encoding
    final simplifiedList =
        simplifiedCoordinates.map((point) => [point.x, point.y]).toList();

    return encodePolyline(simplifiedList);
  }
}
