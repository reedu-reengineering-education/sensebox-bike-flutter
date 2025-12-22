import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/timestamped_sensor_value.dart';
import 'package:sensebox_bike/models/sensor_batch.dart';
import 'package:sensebox_bike/utils/geolocation_utils.dart';

void main() {
  group('matchesGeolocation', () {
    late GeolocationData testGeo;

    setUp(() {
      testGeo = GeolocationData()
        ..latitude = 52.52
        ..longitude = 13.405
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
    });

    test('returns true when timestamp matches within tolerance', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0, 50);

      final result = matchesGeolocation(testGeo, timestamp);

      expect(result, isTrue);
    });

    test('returns false when timestamp exceeds tolerance', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0, 150);

      final result = matchesGeolocation(testGeo, timestamp);

      expect(result, isFalse);
    });

    test('returns true when location matches within tolerance', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
      final latitude = 52.5200005;
      final longitude = 13.4050005;

      final result = matchesGeolocation(
        testGeo,
        timestamp,
        latitude: latitude,
        longitude: longitude,
      );

      expect(result, isTrue);
    });

    test('returns false when location exceeds tolerance', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
      final latitude = 52.53;
      final longitude = 13.405;

      final result = matchesGeolocation(
        testGeo,
        timestamp,
        latitude: latitude,
        longitude: longitude,
      );

      expect(result, isFalse);
    });

    test('returns true when only timestamp provided and matches', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0, 50);

      final result = matchesGeolocation(testGeo, timestamp);

      expect(result, isTrue);
    });

    test('respects custom time tolerance', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0, 200);

      final result = matchesGeolocation(
        testGeo,
        timestamp,
        timeToleranceMs: 300,
      );

      expect(result, isTrue);
    });

    test('respects custom location tolerance', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);
      final latitude = 52.53;
      final longitude = 13.405;

      final result = matchesGeolocation(
        testGeo,
        timestamp,
        latitude: latitude,
        longitude: longitude,
        locationTolerance: 0.01,
      );

      expect(result, isTrue);
    });
  });

  group('findMatchingGeolocation', () {
    late List<GeolocationData> geolocations;

    setUp(() {
      geolocations = [
        GeolocationData()
          ..latitude = 52.52
          ..longitude = 13.405
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
        GeolocationData()
          ..latitude = 52.53
          ..longitude = 13.406
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 1),
        GeolocationData()
          ..latitude = 52.54
          ..longitude = 13.407
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 2),
      ];
    });

    test('returns matching geolocation when found', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0, 50);

      final result = findMatchingGeolocation(geolocations, timestamp);

      expect(result, isNotNull);
      expect(result!.latitude, equals(52.52));
      expect(result.longitude, equals(13.405));
    });

    test('returns null when no match found', () {
      final timestamp = DateTime.utc(2024, 1, 1, 13, 0, 0);

      final result = findMatchingGeolocation(geolocations, timestamp);

      expect(result, isNull);
    });

    test('returns matching geolocation with location criteria', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0, 50);
      final latitude = 52.5200005;
      final longitude = 13.4050005;

      final result = findMatchingGeolocation(
        geolocations,
        timestamp,
        latitude: latitude,
        longitude: longitude,
      );

      expect(result, isNotNull);
      expect(result!.latitude, equals(52.52));
    });

    test('returns null when location does not match', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0, 50);
      final latitude = 52.60;
      final longitude = 13.50;

      final result = findMatchingGeolocation(
        geolocations,
        timestamp,
        latitude: latitude,
        longitude: longitude,
      );

      expect(result, isNull);
    });

    test('returns null for empty list', () {
      final timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0);

      final result = findMatchingGeolocation([], timestamp);

      expect(result, isNull);
    });
  });

  group('findLatestGeolocation', () {
    test('returns latest geolocation when list is not empty', () {
      final geolocations = [
        GeolocationData()
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
        GeolocationData()
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 2),
        GeolocationData()
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 1),
      ];

      final result = findLatestGeolocation(geolocations);

      expect(result, isNotNull);
      expect(result!.timestamp, equals(DateTime.utc(2024, 1, 1, 12, 0, 2)));
    });

    test('returns null when list is empty', () {
      final result = findLatestGeolocation([]);

      expect(result, isNull);
    });

    test('handles single geolocation', () {
      final geolocations = [
        GeolocationData()
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final result = findLatestGeolocation(geolocations);

      expect(result, isNotNull);
      expect(result!.timestamp, equals(DateTime.utc(2024, 1, 1, 12, 0, 0)));
    });

    test('sorts correctly when timestamps are in reverse order', () {
      final geolocations = [
        GeolocationData()
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 2),
        GeolocationData()
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
        GeolocationData()
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 1),
      ];

      final result = findLatestGeolocation(geolocations);

      expect(result, isNotNull);
      expect(result!.timestamp, equals(DateTime.utc(2024, 1, 1, 12, 0, 2)));
    });
  });

  group('getValuesInLookbackWindow', () {
    late List<TimestampedSensorValue> preGpsValues;
    late List<SensorBatch> sensorBatches;

    setUp(() {
      preGpsValues = [
        TimestampedSensorValue(
          values: [1.0],
          timestamp: DateTime.utc(2024, 1, 1, 12, 0, 0),
        ),
        TimestampedSensorValue(
          values: [2.0],
          timestamp: DateTime.utc(2024, 1, 1, 12, 0, 1),
        ),
        TimestampedSensorValue(
          values: [3.0],
          timestamp: DateTime.utc(2024, 1, 1, 12, 0, 2),
        ),
      ];
      sensorBatches = [];
    });

    test('returns all values up to geoTime when lookbackWindow is zero and no previous geolocations', () {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 3);

      final result = getValuesInLookbackWindow(
        geoTime,
        preGpsValues,
        sensorBatches,
        Duration.zero,
      );

      expect(result.length, equals(3));
      expect(result[0], equals([1.0]));
      expect(result[1], equals([2.0]));
      expect(result[2], equals([3.0]));
    });

    test('for zero lookback returns all buffered values before geoTime', () {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);

      final result = getValuesInLookbackWindow(
        geoTime,
        preGpsValues,
        sensorBatches,
        Duration.zero,
      );

      // Returns all values before geoTime (excludes values at exactly geoTime)
      expect(result.length, equals(2));
      expect(result[0], equals([1.0]));
      expect(result[1], equals([2.0]));
    });

    test('for zero lookback excludes values at exactly geoTime', () {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final valuesWithExactMatch = [
        TimestampedSensorValue(
          values: [1.0],
          timestamp: DateTime.utc(2024, 1, 1, 12, 0, 1),
        ),
        TimestampedSensorValue(
          values: [2.0],
          timestamp: DateTime.utc(2024, 1, 1, 12, 0, 2), // Exactly at geoTime
        ),
        TimestampedSensorValue(
          values: [3.0],
          timestamp: DateTime.utc(2024, 1, 1, 12, 0, 3), // After geoTime
        ),
      ];

      final result = getValuesInLookbackWindow(
        geoTime,
        valuesWithExactMatch,
        sensorBatches,
        Duration.zero,
      );

      // Should exclude values at exactly geoTime and after
      expect(result.length, equals(1));
      expect(result[0], equals([1.0]));
    });

    test('for zero lookback returns empty list when buffer is empty', () {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);

      final result = getValuesInLookbackWindow(
        geoTime,
        [],
        sensorBatches,
        Duration.zero,
      );

      expect(result, isEmpty);
    });

    test(
        'for zero lookback returns empty list when geoTime is before all values',
        () {
      final geoTime = DateTime.utc(2023, 12, 31, 12, 0, 0);

      final result = getValuesInLookbackWindow(
        geoTime,
        preGpsValues,
        sensorBatches,
        Duration.zero,
      );

      expect(result, isEmpty);
    });

    test('returns values within lookback window', () {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2, 500);
      final lookbackWindow = const Duration(seconds: 1);

      final result = getValuesInLookbackWindow(
        geoTime,
        preGpsValues,
        sensorBatches,
        lookbackWindow,
      );

      // Window starts at earliest reading (12:00:00), ends at geoTime (12:00:02.500)
      // Should include values from 12:00:01.500 to 12:00:02.500
      expect(result.length, equals(2));
      expect(result[0], equals([2.0])); // 12:00:01 is within window
      expect(result[1], equals([3.0])); // 12:00:02 is within window
    });

    test('returns empty list when geoTime is before earliest reading', () {
      final geoTime = DateTime.utc(2023, 12, 31, 12, 0, 0);
      final lookbackWindow = const Duration(seconds: 1);

      final result = getValuesInLookbackWindow(
        geoTime,
        preGpsValues,
        sensorBatches,
        lookbackWindow,
      );

      expect(result, isEmpty);
    });

    test('uses earliest reading as window start when no other batches', () {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final lookbackWindow = const Duration(seconds: 5);

      final result = getValuesInLookbackWindow(
        geoTime,
        preGpsValues,
        sensorBatches,
        lookbackWindow,
      );

      expect(result.length, equals(3));
    });

    test('uses previous geolocation time as window start when other batches exist', () {
      final previousGeo = GeolocationData()
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 1);
      final batch = SensorBatch(
        geoLocation: previousGeo,
        aggregatedData: {},
        timestamp: DateTime.now(),
      );
      sensorBatches = [batch];

      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final lookbackWindow = const Duration(seconds: 5);

      final result = getValuesInLookbackWindow(
        geoTime,
        preGpsValues,
        sensorBatches,
        lookbackWindow,
      );

      expect(result.length, greaterThan(0));
    });

    test('excludes values before window start', () {
      final previousGeo = GeolocationData()
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 1);
      final batch = SensorBatch(
        geoLocation: previousGeo,
        aggregatedData: {},
        timestamp: DateTime.now(),
      );
      sensorBatches = [batch];

      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2, 500);
      final lookbackWindow = const Duration(milliseconds: 500);

      final result = getValuesInLookbackWindow(
        geoTime,
        preGpsValues,
        sensorBatches,
        lookbackWindow,
      );

      expect(result.length, equals(2));
      expect(result[0], equals([2.0]));
      expect(result[1], equals([3.0]));
    });

    test('excludes values after geoTime', () {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 1);
      final lookbackWindow = const Duration(seconds: 5);

      final result = getValuesInLookbackWindow(
        geoTime,
        preGpsValues,
        sensorBatches,
        lookbackWindow,
      );

      // Window starts at earliest reading (12:00:00), ends at geoTime (12:00:01)
      // Should include values at 12:00:00 and 12:00:01, but not 12:00:02
      expect(result.length, equals(2));
      expect(result[0], equals([1.0]));
      expect(result[1], equals([2.0]));
    });

    test('includes values at exactly geoTime for non-zero lookback', () {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final lookbackWindow = const Duration(seconds: 5);
      final valuesWithExactMatch = [
        TimestampedSensorValue(
          values: [1.0],
          timestamp: DateTime.utc(2024, 1, 1, 12, 0, 1),
        ),
        TimestampedSensorValue(
          values: [2.0],
          timestamp: DateTime.utc(2024, 1, 1, 12, 0, 2), // Exactly at geoTime
        ),
        TimestampedSensorValue(
          values: [3.0],
          timestamp: DateTime.utc(2024, 1, 1, 12, 0, 3), // After geoTime
        ),
      ];

      final result = getValuesInLookbackWindow(
        geoTime,
        valuesWithExactMatch,
        sensorBatches,
        lookbackWindow,
      );

      // Should include values up to and including geoTime
      expect(result.length, equals(2));
      expect(result[0], equals([1.0]));
      expect(result[1], equals([2.0]));
    });

    test('handles empty preGpsValues with no batches', () {
      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 0);
      final lookbackWindow = const Duration(seconds: 1);

      final result = getValuesInLookbackWindow(
        geoTime,
        [],
        sensorBatches,
        lookbackWindow,
      );

      expect(result, isEmpty);
    });

    test('ignores batches with timestamp within 100ms of geoTime', () {
      final closeGeo = GeolocationData()
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 2, 50);
      final closeBatch = SensorBatch(
        geoLocation: closeGeo,
        aggregatedData: {},
        timestamp: DateTime.now(),
      );
      sensorBatches = [closeBatch];

      final geoTime = DateTime.utc(2024, 1, 1, 12, 0, 2);
      final lookbackWindow = const Duration(seconds: 5);

      final result = getValuesInLookbackWindow(
        geoTime,
        preGpsValues,
        sensorBatches,
        lookbackWindow,
      );

      expect(result.length, equals(3));
    });
  });
}

