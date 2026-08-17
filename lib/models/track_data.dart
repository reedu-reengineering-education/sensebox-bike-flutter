import 'dart:math';

import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:isar_community/isar.dart';
import 'package:sensebox_bike/utils/distance_calculation_utils.dart';
import 'package:simplify/simplify.dart';

part 'track_data.g.dart';

@Collection()
class TrackData {
  Id id = Isar.autoIncrement;

  @Backlink(to: "track")
  final geolocations = IsarLinks<GeolocationData>();

  // Batch Upload tracking properties - use integers that Isar handles better
  // (int? is used instead of bool? to avoid Isar's nullable boolean bug)
  int? uploaded; // 0 = false, 1 = true, null = null
  int? uploadAttempts; // null = 0 attempts
  DateTime? lastUploadAttempt;

  @Index()
  int? isDirectUpload; // 0 = false, 1 = true, null = null

  /// Collection strategy used for this track (`gpsDriven`, `periodic`, `onTap`).
  /// Null on legacy tracks means GPS-driven aggregation.
  String? dataCollectionMode;

  /// Interval in seconds when [dataCollectionMode] is `periodic`.
  int? collectionIntervalSeconds;

  // Cached aggregates, computed once via [applyComputedAggregates] when a
  // recording finishes (see TrackService.cacheTrackAggregates) or during a
  // one-time backfill for tracks recorded before these fields existed. This
  // lets list/summary screens read plain columns instead of walking every
  // GeolocationData row (and re-running distance/polyline simplification)
  // on every render - that walk was the cause of the app slowing down /
  // crashing once a user has a lot of tracks.
  double? cachedDistanceKm;
  int? cachedDurationMs;
  int? cachedPointCount;
  @Index()
  DateTime? cachedStartTimestamp;
  DateTime? cachedEndTimestamp;
  String? cachedPolyline;

  // Computed getters that provide boolean behavior
  @ignore
  bool get isUploaded => uploaded == 1;

  @ignore
  bool get isDirectUploadTrack =>
      isDirectUpload != 0; // null = true, 1 = true, 0 = false

  @ignore
  int get uploadAttemptsCount {
    final attempts = uploadAttempts ?? 0;
    // Handle corrupted negative values by treating them as 0
    return attempts < 0 ? 0 : attempts;
  }

  /// True once this track has at least one GeolocationData row. Prefers the
  /// cached count so it doesn't need to load the full link just to check.
  @ignore
  bool get hasGeolocationData => cachedPointCount != null
      ? cachedPointCount! > 0
      : geolocations.isNotEmpty;

  /// Timestamp of the first point, or null for an empty track. Falls back to
  /// a live lookup (loads the full link) for tracks not yet cached.
  @ignore
  DateTime? get startTimestamp =>
      cachedStartTimestamp ??
      (geolocations.isNotEmpty ? geolocations.first.timestamp : null);

  /// Timestamp of the last point, or null for an empty track. Falls back to
  /// a live lookup (loads the full link) for tracks not yet cached.
  @ignore
  DateTime? get endTimestamp =>
      cachedEndTimestamp ??
      (geolocations.isNotEmpty ? geolocations.last.timestamp : null);

  @ignore
  Duration get duration {
    if (cachedDurationMs != null) {
      return Duration(milliseconds: cachedDurationMs!);
    }
    return Duration(
        milliseconds: geolocations.isNotEmpty
            ? geolocations.last.timestamp.millisecondsSinceEpoch -
                geolocations.first.timestamp.millisecondsSinceEpoch
            : 0);
  }

  @ignore
  double get distance => cachedDistanceKm ?? getDistance(geolocations.toList());

  double calculateTolerance(int numberOfCoordinates) {
    // Base tolerance for small datasets
    const double baseTolerance = 0.00001;
    // Growth factor for exponential scaling
    const double growthFactor = 1.01;

    return baseTolerance * pow(growthFactor, (numberOfCoordinates / 1000));
  }

  @ignore
  String get encodedPolyline => cachedPolyline ?? _computeEncodedPolyline();

  String _computeEncodedPolyline() {
    final List<Point<double>> coordinates =
        convertToSimplifyPoints(geolocations.toList());

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

    // Dynamic simplification loop: grow the tolerance each pass until the
    // encoded polyline fits Mapbox's static-map URL budget (or we give up
    // once the route would be too coarse / after a bounded number of
    // attempts, so this always terminates regardless of track shape).
    double tolerance = calculateTolerance(coordinates.length);
    String polyline;
    List<Point<double>> simplifiedCoordinates;
    var attempts = 0;
    const maxAttempts = 30;
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
      tolerance *= 1.5;
      attempts++;
    } while (polyline.length > 7950 &&
        tolerance <= 0.005 &&
        attempts < maxAttempts);

    return polyline;
  }

  /// Recomputes the cached* fields from [geolocations], which must already
  /// be loaded (via `await geolocations.load()`). Does not persist - the
  /// caller is expected to `put` the track in a write transaction.
  void applyComputedAggregates() {
    final geos = geolocations.toList();
    cachedPointCount = geos.length;

    if (geos.isEmpty) {
      cachedStartTimestamp = null;
      cachedEndTimestamp = null;
      cachedDurationMs = 0;
      cachedDistanceKm = 0;
      cachedPolyline = '';
      return;
    }

    final start = geos.first.timestamp;
    final end = geos.last.timestamp;
    cachedStartTimestamp = start;
    cachedEndTimestamp = end;
    cachedDurationMs = end.difference(start).inMilliseconds;
    cachedDistanceKm = getDistance(geos);
    cachedPolyline = _computeEncodedPolyline();
  }
}
