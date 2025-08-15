import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:turf/turf.dart';
import 'package:turf/turf.dart' as Turf;
import 'package:sensebox_bike/utils/distance_calculation_utils.dart';

double getDistance(List<GeolocationData> geolocations,
    {Unit unit = Unit.kilometers}) {

  return calculateDistanceWithSimplify(geolocations);
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


