import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/utils/geolocation_utils.dart';

void main() {
  group('shouldSkipGeolocationByTime', () {
    GeolocationData createGeolocation({
      double? latitude,
      double? longitude,
      DateTime? timestamp,
      double? speed,
    }) {
      return GeolocationData()
        ..latitude = latitude ?? 52.5200
        ..longitude = longitude ?? 13.4050
        ..timestamp = timestamp ?? DateTime.now().toUtc()
        ..speed = speed ?? 0.0;
    }

    group('duplicate timestamp filtering', () {
      test('should skip if timestamps are identical', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(timestamp: now);

        final result = shouldSkipGeolocationByTime(
          currentPosition,
          lastPosition,
        );

        expect(result, true);
      });

      test('should not skip if timestamps differ', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(seconds: 10)),
        );

        final result = shouldSkipGeolocationByTime(
          currentPosition,
          lastPosition,
        );

        expect(result, false);
      });
    });

    group('1 second interval enforcement (all platforms)', () {
      test('should skip if less than 1 second has passed', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(milliseconds: 500)),
        );

        final result = shouldSkipGeolocationByTime(
          currentPosition,
          lastPosition,
        );

        expect(result, true);
      });

      test('should not skip if exactly 1 second has passed', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(seconds: 1)),
        );

        final result = shouldSkipGeolocationByTime(
          currentPosition,
          lastPosition,
        );

        expect(result, false);
      });

      test('should not skip if more than 1 second has passed', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(seconds: 2)),
        );

        final result = shouldSkipGeolocationByTime(
          currentPosition,
          lastPosition,
        );

        expect(result, false);
      });

      test('should skip if exactly 0.999 seconds have passed', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(milliseconds: 999)),
        );

        final result = shouldSkipGeolocationByTime(
          currentPosition,
          lastPosition,
        );

        expect(result, true);
      });

      test('should skip regardless of distance', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(
          timestamp: now,
          latitude: 52.5200,
          longitude: 13.4050,
        );
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(milliseconds: 500)),
          latitude: 52.5300,
          longitude: 13.4150,
        );

        final result = shouldSkipGeolocationByTime(
          currentPosition,
          lastPosition,
        );

        expect(result, true);
      });
    });

    group('edge cases', () {
      test('should handle negative time difference correctly', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(
          timestamp: now.add(const Duration(milliseconds: 500)),
        );
        final currentPosition = createGeolocation(timestamp: now);

        final result = shouldSkipGeolocationByTime(
          currentPosition,
          lastPosition,
        );

        expect(result, true);
      });

      test('should handle very large time differences', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(hours: 1)),
        );

        final result = shouldSkipGeolocationByTime(
          currentPosition,
          lastPosition,
        );

        expect(result, false);
      });

      test('should handle same location with different timestamps', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(
          timestamp: now,
          latitude: 52.5200,
          longitude: 13.4050,
        );
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(milliseconds: 500)),
          latitude: 52.5200,
          longitude: 13.4050,
        );

        final result = shouldSkipGeolocationByTime(
          currentPosition,
          lastPosition,
        );

        expect(result, true);
      });
    });
  });
}
