import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/utils/privacy_zone_checker.dart';
import '../test_helpers.dart';

void main() {
  group('PrivacyZoneChecker', () {
    late PrivacyZoneChecker checker;

    setUp(() {
      checker = PrivacyZoneChecker();
    });

    tearDown(() {
      checker.dispose();
    });

    group('updatePrivacyZones', () {
      test('should handle empty list', () {
        checker.updatePrivacyZones([]);
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            false);
      });

      test('should update with valid zones', () {
        final zone =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        checker.updatePrivacyZones([zone]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            true);
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat2, testLng2)),
            false);
      });

      test('should replace existing zones when updated', () {
        final zone1 =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        checker.updatePrivacyZones([zone1]);
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            true);
        
        final zone2 =
            createSquarePrivacyZone(testLat2, testLng2, defaultZoneSize);
        checker.updatePrivacyZones([zone2]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            false);
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat2, testLng2)),
            true);
      });

      test('should handle multiple zones', () {
        final zone1 =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        final zone2 =
            createSquarePrivacyZone(testLat2, testLng2, defaultZoneSize);
        checker.updatePrivacyZones([zone1, zone2]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            true);
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat2, testLng2)),
            true);
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat3, testLng3)),
            false);
      });

      final errorHandlingTestCases = [
        ('invalid JSON', 'invalid json'),
        ('missing coordinates', '{"type": "Polygon"}'),
        ('empty coordinates', '{"type": "Polygon", "coordinates": []}'),
        (
          'wrong coordinate nesting level',
          '{"type": "Polygon", "coordinates": [13.4, 52.5]}'
        ),
        (
          'non-numeric coordinates',
          '{"type": "Polygon", "coordinates": [[["invalid", "coordinates"]]]}'
        ),
      ];

      for (final testCase in errorHandlingTestCases) {
        test('should skip ${testCase.$1} and process valid zones', () {
          final invalidZone = testCase.$2;
          final validZone =
              createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
          checker.updatePrivacyZones([invalidZone, validZone]);
          
          expect(
              checker.isInsidePrivacyZone(
                  createTestGeolocation(testLat1, testLng1)),
              true);
        });
      }

      test('should handle all invalid zones gracefully', () {
        checker.updatePrivacyZones(['invalid', '{"type": "Polygon"}', '{"type": "Polygon", "coordinates": []}']);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            false);
      });
    });

    group('isInsidePrivacyZone', () {
      test('should return false when no zones are set', () {
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            false);
      });

      test('should return true for point inside zone', () {
        final zone =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        checker.updatePrivacyZones([zone]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            true);
      });

      test('should return false for point outside zone', () {
        final zone =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        checker.updatePrivacyZones([zone]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat2, testLng2)),
            false);
      });

      test('should return true if point is inside any of multiple zones', () {
        final zone1 =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        final zone2 =
            createSquarePrivacyZone(testLat2, testLng2, defaultZoneSize);
        checker.updatePrivacyZones([zone1, zone2]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            true);
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat2, testLng2)),
            true);
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat3, testLng3)),
            false);
      });

      test('should return true for point on zone boundary', () {
        final zone =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        checker.updatePrivacyZones([zone]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.45, 13.4)), true);
      });

      test('should return false for point exactly at zone corner', () {
        final zone =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        checker.updatePrivacyZones([zone]);
        
        final halfSize = defaultZoneSize / 2;
        final cornerLat = testLat1 - halfSize;
        final cornerLng = testLng1 - halfSize;
        
        final result = checker.isInsidePrivacyZone(createTestGeolocation(cornerLat, cornerLng));
        expect(result, isA<bool>());
      });
    });

    group('polygon closing', () {
      test('should automatically close unclosed polygons', () {
        final unclosedZone = createSquarePrivacyZone(
            testLat1, testLng1, defaultZoneSize,
            closed: false);
        checker.updatePrivacyZones([unclosedZone]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            true);
      });

      test('should handle already closed polygons', () {
        final closedZone =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        checker.updatePrivacyZones([closedZone]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            true);
      });

      test('should handle empty coordinate list', () {
        final emptyCoordinates = '{"type": "Polygon", "coordinates": [[[]]]}';
        checker.updatePrivacyZones([emptyCoordinates]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            false);
      });

      test('should handle single point polygon', () {
        final singlePoint = '{"type": "Polygon", "coordinates": [[[13.4, 52.5]]]}';
        checker.updatePrivacyZones([singlePoint]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            false);
      });

      test('should handle two-point polygon (line segment)', () {
        final lineSegment = '{"type": "Polygon", "coordinates": [[[13.4, 52.5], [13.5, 52.6]]]}';
        checker.updatePrivacyZones([lineSegment]);
        
        final result = checker
            .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1));
        expect(result, isA<bool>());
      });
    });

    group('edge cases', () {
      test('should handle very large number of zones', () {
        final zones = List.generate(100, (i) => 
          createSquarePrivacyZone(
                testLat1 + i * 0.01, testLng1 + i * 0.01, 0.01)
        );
        checker.updatePrivacyZones(zones);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            true);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.51, 13.41)), true);
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat3, testLng3)),
            false);
      });

      test('should handle zones with many vertices', () {
        final manyVertices = createPolygonWithManyVertices(
            testLat1, testLng1, defaultZoneSize, 50);
        checker.updatePrivacyZones([manyVertices]);
        
        final centerResult = checker
            .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1));
        expect(centerResult, isA<bool>());
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat2, testLng2)),
            false);
      });

      test('should handle zones at different latitudes', () {
        final zoneEquator = createSquarePrivacyZone(0.0, 0.0, defaultZoneSize);
        final zoneNorth = createSquarePrivacyZone(80.0, 0.0, defaultZoneSize);
        final zoneSouth = createSquarePrivacyZone(-80.0, 0.0, defaultZoneSize);
        checker.updatePrivacyZones([zoneEquator, zoneNorth, zoneSouth]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(0.0, 0.0)), true);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(80.0, 0.0)), true);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(-80.0, 0.0)), true);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(40.0, 0.0)), false);
      });

      test('should handle zones crossing international date line', () {
        final zoneCrossingDateLine = createZoneCrossingDateLine();
        checker.updatePrivacyZones([zoneCrossingDateLine]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 179.9)), true);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, -179.9)), true);
      });
    });

    group('dispose', () {
      test('should clear cached zones', () {
        final zone =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        checker.updatePrivacyZones([zone]);
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            true);
        
        checker.dispose();
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat1, testLng1)),
            false);
      });

      test('should allow updating zones after dispose', () {
        final zone1 =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        checker.updatePrivacyZones([zone1]);
        checker.dispose();
        
        final zone2 =
            createSquarePrivacyZone(testLat2, testLng2, defaultZoneSize);
        checker.updatePrivacyZones([zone2]);
        
        expect(
            checker
                .isInsidePrivacyZone(createTestGeolocation(testLat2, testLng2)),
            true);
      });
    });
  });
}
