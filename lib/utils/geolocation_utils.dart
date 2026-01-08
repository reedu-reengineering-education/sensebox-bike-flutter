import 'package:sensebox_bike/models/geolocation_data.dart';

const int geolocationMinimumIntervalMs = 1000;

bool shouldSkipGeolocationByTime(
  GeolocationData currentGeolocation,
  GeolocationData lastEmittedGeolocation,
) {
  final lastTimestamp = lastEmittedGeolocation.timestamp.millisecondsSinceEpoch;
  final currentTimestamp = currentGeolocation.timestamp.millisecondsSinceEpoch;

  if (lastTimestamp == currentTimestamp) {
    return true;
  }

  final timeDiff = (currentTimestamp - lastTimestamp).abs();

  if (timeDiff < geolocationMinimumIntervalMs) {
    return true;
  }

  return false;
}
