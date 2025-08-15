
import 'dart:math';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:simplify/simplify.dart';

List<Point<double>> convertToSimplifyPoints(
    List<GeolocationData> geolocations) {
  return geolocations
      .map((geolocation) =>
          Point<double>(geolocation.latitude, geolocation.longitude))
      .toList();
}

/// Calculates distance using simplify to reduce noise and remove redundant points
double calculateDistanceWithSimplify(List<GeolocationData> geolocations) {
  if (geolocations.length < 2) return 0.0;

  // Use simplify to reduce noise and remove redundant points
  final simplifiedPoints = convertToSimplifyPoints(geolocations);
  final simplified = simplify<Point<double>>(
    simplifiedPoints,
    tolerance: 0.001, 
    highestQuality: false,
  );

  // Convert back to GeolocationData for distance calculation
  final simplifiedGeolocations =
      convertSimplifiedPointsToGeolocations(simplified, geolocations);

  // Calculate distance using simplified points
  double tempDistance = 0.0;
  for (int i = 0; i < simplifiedGeolocations.length - 1; i++) {
    GeolocationData start = simplifiedGeolocations[i];
    GeolocationData end = simplifiedGeolocations[i + 1];

    tempDistance += _calculateHaversineDistance(
      start.latitude, start.longitude,
      end.latitude, end.longitude,
    );
  }

  return tempDistance;
}

/// Converts simplified Point objects back to GeolocationData
/// Finds the closest original geolocation point for each simplified point
List<GeolocationData> convertSimplifiedPointsToGeolocations(
  List<Point<double>> simplifiedPoints,
  List<GeolocationData> originalGeolocations,
) {
  List<GeolocationData> result = [];

  for (final point in simplifiedPoints) {
    // Find the closest original geolocation point
    GeolocationData? closest;
    double minDistance = double.infinity;

    for (final geo in originalGeolocations) {
      final distance = _calculateHaversineDistance(
        geo.latitude,
        geo.longitude,
        point.x,
        point.y,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closest = geo;
      }
    }

    if (closest != null) {
      result.add(closest);
    }
  }

  return result;
}

/// Calculates Haversine distance between two points in kilometers
double _calculateHaversineDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadius = 6371.0; // Earth's radius in kilometers

  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

/// Converts degrees to radians
double _degreesToRadians(double degrees) {
  return degrees * (pi / 180.0);
}

