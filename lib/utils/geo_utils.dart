import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/utils/distance_calculation_utils.dart';

double getDistance(List<GeolocationData> geolocations) {
  return calculateDistanceWithSimplify(geolocations);
}


