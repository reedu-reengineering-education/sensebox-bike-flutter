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
            (geolocation) => Point(geolocation.latitude, geolocation.longitude))
        .toList();

    if (coordinates.isEmpty) {
      return "";
    }
    // If there is only one location, or all locations are the same
    if ((coordinates.length == 1) || (coordinates.toSet().length == 1)) {
      final singlePoint = coordinates.first;
      // Add a tiny offset to the second point
      // to ensure Mapbox can render it
      final offset = 0.00005;
      final repeatedPoints = [
        [singlePoint.x, singlePoint.y],
        [singlePoint.x, singlePoint.y + offset]
      ];
      return encodePolyline(repeatedPoints);
    }

    if (coordinates.length < 10) {
      final List<List<num>> castedCoordinates = geolocations
          .map((geolocation) => [geolocation.latitude, geolocation.longitude])
          .toList();

      return encodePolyline(castedCoordinates);
    }

    // Dynamic simplification loop
    double tolerance = calculateTolerance(coordinates.length);
    String polyline;
    List<Point<double>> simplifiedCoordinates;
    do {
      simplifiedCoordinates = simplify<Point<double>>(
        coordinates,
        tolerance: tolerance,
        highestQuality: false,
      );
      final simplifiedList =
          simplifiedCoordinates.map((point) => [point.x, point.y]).toList();
      polyline = encodePolyline(simplifiedList);
      // Mapbox API URL lenght limit is 8192 bytes,
      // other parts of URL are 197 bytes long
      // which leaves us with 7995 bytes for the polyline
    } while (polyline.length > 7950 && tolerance > 0.005);

    return polyline;
  }
}
