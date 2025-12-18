import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/timestamped_sensor_value.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
import 'package:sensebox_bike/utils/date_utils.dart';

bool matchesGeolocation(
  GeolocationData geo,
  DateTime timestamp, {
  double? latitude,
  double? longitude,
  int timeToleranceMs = 100,
  double locationTolerance = 0.000001,
}) {
  final timeDiff = (geo.timestamp.difference(timestamp)).abs();
  if (timeDiff.inMilliseconds >= timeToleranceMs) {
    return false;
  }

  if (latitude != null && longitude != null) {
    final sameLocation = (geo.latitude - latitude).abs() < locationTolerance &&
        (geo.longitude - longitude).abs() < locationTolerance;
    return sameLocation;
  }

  return true;
}

GeolocationData? findMatchingGeolocation(
  List<GeolocationData> geolocations,
  DateTime timestamp, {
  double? latitude,
  double? longitude,
  int timeToleranceMs = 100,
  double locationTolerance = 0.000001,
}) {
  try {
    return geolocations.firstWhere((geo) => matchesGeolocation(
          geo,
          timestamp,
          latitude: latitude,
          longitude: longitude,
          timeToleranceMs: timeToleranceMs,
          locationTolerance: locationTolerance,
        ));
  } catch (e) {
    return null;
  }
}

GeolocationData? findLatestGeolocation(List<GeolocationData> geolocations) {
  if (geolocations.isEmpty) {
    return null;
  }

  return geolocations
      .reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
}

List<List<double>> getValuesInLookbackWindow(
  DateTime geoTime,
  List<TimestampedSensorValue> preGpsValues,
  List<SensorBatch> sensorBatches,
  Duration lookbackWindow,
) {
  final geoTimeUtc = toUtc(geoTime);

  // For sensors without a lookback window, only use values collected after the
  // previous geolocation (if any) up to the current geolocation time.
  if (lookbackWindow == Duration.zero) {
    final previousGeoTime = sensorBatches
        .map((b) => toUtc(b.geoLocation.timestamp))
        // Ignore geolocations that are effectively the same moment
        .where((t) =>
            t.isBefore(geoTimeUtc.subtract(const Duration(milliseconds: 100))))
        .fold<DateTime?>(null, (latest, t) {
      if (latest == null || t.isAfter(latest)) {
        return t;
      }
      return latest;
    });

    return preGpsValues
        .where((entry) {
          final ts = toUtc(entry.timestamp);
          final afterPrevious =
              previousGeoTime == null || ts.isAfter(previousGeoTime);
          final beforeOrAtCurrent = !ts.isAfter(geoTimeUtc);
          return afterPrevious && beforeOrAtCurrent;
        })
        .map((entry) => entry.values)
        .toList();
  }

  final otherBatches = sensorBatches.where((b) {
    return (b.geoLocation.timestamp.difference(geoTimeUtc))
            .abs()
            .inMilliseconds >
        100;
  }).toList();

  final DateTime windowStart;
  if (otherBatches.isEmpty) {
    if (preGpsValues.isEmpty) {
      windowStart = geoTimeUtc.subtract(const Duration(days: 1));
    } else {
      final earliestReading = preGpsValues
          .map((e) => e.timestamp)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      windowStart = earliestReading.isAfter(geoTimeUtc)
          ? geoTimeUtc.subtract(const Duration(days: 1))
          : earliestReading;
    }
  } else {
    final previousGeoTime = otherBatches
        .map((b) => b.geoLocation.timestamp)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    windowStart = toUtc(previousGeoTime);
  }

  return preGpsValues
      .where((entry) =>
          !entry.timestamp.isBefore(windowStart) &&
          !entry.timestamp.isAfter(geoTimeUtc))
      .map((entry) => entry.values)
      .toList();
}

