import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:turf/turf.dart';
import 'package:turf/turf.dart' as Turf;

double getDistance(List<GeolocationData> geolocations,
    {Unit unit = Unit.kilometers}) {
  double tempDistance = 0.0;

  for (int i = 0; i < geolocations.length - 1; i++) {
    GeolocationData start = geolocations[i];
    GeolocationData end = geolocations[i + 1];

    var from = Point(coordinates: Position(start.longitude, start.latitude));
    var to = Point(coordinates: Position(end.longitude, end.latitude));

    tempDistance += distance(from, to, unit);
  }

  return tempDistance;
}

bool isInsidePrivacyZone(
    Iterable<Turf.Polygon> privacyZones, GeolocationData data) {
  // Close the privacy zones
  final closedZones = privacyZones.map((e) {
    final coordinates = e.coordinates.first.first;
    e.coordinates.first.add(coordinates);
    return e;
  }).toList();

  // Check if the current location is in a privacy zone
  for (var zone in closedZones) {
    if (Turf.booleanPointInPolygon(
        Turf.Position(data.longitude, data.latitude), zone)) {
      return true;
    }
  }

  return false;
}
