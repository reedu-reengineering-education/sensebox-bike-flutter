import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/utils/distance_calculation_utils.dart';
import '../test_helpers.dart';

void main() {
  group('Distance Calculation Utils', () {
    group('convertToSimplifyPoints', () {
      test('should return empty list for empty input', () {
        final result = convertToSimplifyPoints([]);
        expect(result, isEmpty);
      });

      test('should convert single geolocation to Point with correct coordinates', () {
        final geolocations = [
          createTestGeolocation(52.5200, 13.4050),
        ];

        final result = convertToSimplifyPoints(geolocations);
        expect(result, hasLength(1));
        expect(result.first.x, equals(52.5200));
        expect(result.first.y, equals(13.4050));
      });

      test('should convert multiple geolocations to Points with correct coordinates', () {
        final geolocations = [
          createTestGeolocation(52.5200, 13.4050),
          createTestGeolocation(52.5201, 13.4051),
        ];

        final result = convertToSimplifyPoints(geolocations);
        expect(result, hasLength(2));
        expect(result[0].x, equals(52.5200));
        expect(result[0].y, equals(13.4050));
        expect(result[1].x, equals(52.5201));
        expect(result[1].y, equals(13.4051));
      });
    });

    group('calculateDistanceWithSimplify', () {
      test('should return 0.0 for empty geolocation list', () {
        final result = calculateDistanceWithSimplify([]);
        expect(result, equals(0.0));
      });

      test('should return 0.0 for single geolocation (no distance to calculate)', () {
        final geolocations = [
          createTestGeolocation(52.5200, 13.4050),
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, equals(0.0));
      });

      test('should calculate accurate distance between two nearby points', () {
        // Use coordinates that give approximately 1.6 meters
        final geolocations = [
          createTestGeolocation(52.5200, 13.4050),
          createTestGeolocation(52.5200126, 13.4050126),
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, greaterThan(0.0));
        // Distance should be approximately 1.6 meters (actual calculated value)
        expect(result, closeTo(0.00164, 0.0001));
      });

      test('should calculate cumulative distance along multiple points', () {
        // Use coordinates that give approximately 3.3 meters total
        final geolocations = [
          createTestGeolocation(52.5200, 13.4050),
          createTestGeolocation(52.5200126, 13.4050126),
          createTestGeolocation(52.5200252, 13.4050252),
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, greaterThan(0.0));
        // Total distance should be approximately 3.3 meters (actual calculated value)
        expect(result, closeTo(0.00328, 0.0001));
      });

      test('should reduce GPS noise and calculate accurate distance using simplify algorithm', () {
        // Create a straight line with some noise, using coordinates that give ~3.3 meters total
        final geolocations = [
          createTestGeolocation(52.5200, 13.4050),
          createTestGeolocation(52.5200063, 13.4050063),
          createTestGeolocation(52.5200126, 13.4050126),
          createTestGeolocation(52.5200189, 13.4050189),
          createTestGeolocation(52.5200252, 13.4050252),
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, greaterThan(0.0));
        // Distance should be approximately 3.3 meters (actual calculated value)
        expect(result, closeTo(0.00328, 0.0001));
      });

      test('should calculate large geographic distances accurately (Berlin to Munich)', () {
        // Berlin to Munich (approximately 500 km)
        final geolocations = [
          createTestGeolocation(52.5200, 13.4050), // Berlin
          createTestGeolocation(48.1351, 11.5820), // Munich
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, greaterThan(400.0)); // Should be around 500 km
        expect(result, lessThan(600.0));
      });
    });

    group('Haversine distance calculation', () {
      test('should return 0.0 for identical coordinates (zero distance)', () {
        // This tests the internal _calculateHaversineDistance function indirectly
        final geolocations = [
          createTestGeolocation(52.5200, 13.4050),
          createTestGeolocation(52.5200, 13.4050),
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, equals(0.0));
      });

      test('should calculate extreme distance between antipodal points (half Earth circumference)', () {
        // This tests the internal _calculateHaversineDistance function indirectly
        final geolocations = [
          createTestGeolocation(0.0, 0.0),
          createTestGeolocation(0.0, 180.0),
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        // Distance should be approximately half the Earth's circumference
        expect(result, closeTo(20037.0, 100.0)); // ±100 km tolerance
      });
    });

    group('Movement speed filtering', () {
      test('should filter out impossible speed jumps', () {
        // Create GPS data with realistic timestamps
        final baseTime = DateTime.now();
        final geolocations = [
          GeolocationData()
            ..latitude = 52.5200
            ..longitude = 13.4050
            ..timestamp = baseTime
            ..speed = 0.0,
          // Realistic movement: 100m in 10 seconds (36 km/h)
          GeolocationData()
            ..latitude = 52.5209
            ..longitude = 13.4050
            ..timestamp = baseTime.add(Duration(seconds: 10))
            ..speed = 0.0,
          // Impossible jump: 1000km in 1 second
          GeolocationData()
            ..latitude = 62.5200
            ..longitude = 23.4050
            ..timestamp = baseTime.add(Duration(seconds: 11))
            ..speed = 0.0,
          // Back to realistic movement
          GeolocationData()
            ..latitude = 52.5218
            ..longitude = 13.4050
            ..timestamp = baseTime.add(Duration(seconds: 21))
            ..speed = 0.0,
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, greaterThan(0.0));
        // Should only include realistic movements, not the impossible jump
        expect(result, lessThan(1.0)); // Should be much less than 1000km
      });

      test('should handle test data with identical timestamps', () {
        // Test data typically has identical timestamps
        final geolocations = [
          createTestGeolocation(52.5200, 13.4050),
          createTestGeolocation(52.5200126, 13.4050126),
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, greaterThan(0.0));
        // Should calculate distance normally for test data
        expect(result, closeTo(0.00164, 0.0001));
      });
    });

    group('Edge cases', () {
      test('should handle micro-level coordinate precision (very small distances)', () {
        final geolocations = [
          createTestGeolocation(52.5200000000, 13.4050000000),
          createTestGeolocation(52.5200000001, 13.4050000001),
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, greaterThan(0.0));
        expect(result, lessThan(0.0001)); // Very small distance
      });

      test('should handle coordinates near geographic poles (high latitude edge case)', () {
        final geolocations = [
          createTestGeolocation(90.0, 0.0), // North Pole
          createTestGeolocation(89.9, 0.0), // Near North Pole
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, greaterThan(0.0));
        expect(
            result,
            closeTo(11.119,
                0.001)); // Approximately 11.119 km (actual calculated value)
      });

      test('should handle coordinates crossing international date line (longitude edge case)', () {
        final geolocations = [
          createTestGeolocation(0.0, 179.9),
          createTestGeolocation(0.0, -179.9),
        ];

        final result = calculateDistanceWithSimplify(geolocations);
        expect(result, greaterThan(0.0));
        expect(
            result,
            closeTo(22.239,
                0.001)); // Approximately 22.239 km (actual calculated value)
      });
    });
  });
}
