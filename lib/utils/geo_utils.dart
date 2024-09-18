import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:turf/turf.dart';

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
