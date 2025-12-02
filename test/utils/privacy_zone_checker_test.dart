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
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), false);
      });

      test('should update with valid zones', () {
        final zone = _createSquareZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([zone]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(53.0, 14.0)), false);
      });

      test('should replace existing zones when updated', () {
        final zone1 = _createSquareZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([zone1]);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
        
        final zone2 = _createSquareZone(53.0, 14.0, 0.1);
        checker.updatePrivacyZones([zone2]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), false);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(53.0, 14.0)), true);
      });

      test('should handle multiple zones', () {
        final zone1 = _createSquareZone(52.5, 13.4, 0.1);
        final zone2 = _createSquareZone(53.0, 14.0, 0.1);
        checker.updatePrivacyZones([zone1, zone2]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(53.0, 14.0)), true);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(54.0, 15.0)), false);
      });

      test('should skip invalid JSON and process valid zones', () {
        final invalidJson = 'invalid json';
        final validZone = _createSquareZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([invalidJson, validZone]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
      });

      test('should skip zones with missing coordinates', () {
        final invalidZone = '{"type": "Polygon"}';
        final validZone = _createSquareZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([invalidZone, validZone]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
      });

      test('should skip zones with empty coordinates', () {
        final emptyZone = '{"type": "Polygon", "coordinates": []}';
        final validZone = _createSquareZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([emptyZone, validZone]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
      });

      test('should handle all invalid zones gracefully', () {
        checker.updatePrivacyZones(['invalid', '{"type": "Polygon"}', '{"type": "Polygon", "coordinates": []}']);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), false);
      });
    });

    group('isInsidePrivacyZone', () {
      test('should return false when no zones are set', () {
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), false);
      });

      test('should return true for point inside zone', () {
        final zone = _createSquareZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([zone]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
      });

      test('should return false for point outside zone', () {
        final zone = _createSquareZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([zone]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(53.0, 14.0)), false);
      });

      test('should return true if point is inside any of multiple zones', () {
        final zone1 = _createSquareZone(52.5, 13.4, 0.1);
        final zone2 = _createSquareZone(53.0, 14.0, 0.1);
        checker.updatePrivacyZones([zone1, zone2]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(53.0, 14.0)), true);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(54.0, 15.0)), false);
      });

      test('should return true for point on zone boundary', () {
        final zone = _createSquareZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([zone]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.4, 13.4)), true);
      });
    });

    group('polygon closing', () {
      test('should automatically close unclosed polygons', () {
        final unclosedZone = _createUnclosedZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([unclosedZone]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
      });

      test('should handle already closed polygons', () {
        final closedZone = _createSquareZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([closedZone]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
      });

      test('should handle empty coordinate list', () {
        final emptyCoordinates = '{"type": "Polygon", "coordinates": [[[]]]}';
        checker.updatePrivacyZones([emptyCoordinates]);
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), false);
      });
    });

    group('dispose', () {
      test('should clear cached zones', () {
        final zone = _createSquareZone(52.5, 13.4, 0.1);
        checker.updatePrivacyZones([zone]);
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), true);
        
        checker.dispose();
        
        expect(checker.isInsidePrivacyZone(createTestGeolocation(52.5, 13.4)), false);
      });
    });
  });
}

String _createSquareZone(double centerLat, double centerLng, double size) {
  final halfSize = size / 2;
  final coordinates = [
    [centerLng - halfSize, centerLat - halfSize],
    [centerLng + halfSize, centerLat - halfSize],
    [centerLng + halfSize, centerLat + halfSize],
    [centerLng - halfSize, centerLat + halfSize],
    [centerLng - halfSize, centerLat - halfSize],
  ];
  
  return '{"type": "Polygon", "coordinates": [$coordinates]}';
}

String _createUnclosedZone(double centerLat, double centerLng, double size) {
  final halfSize = size / 2;
  final coordinates = [
    [centerLng - halfSize, centerLat - halfSize],
    [centerLng + halfSize, centerLat - halfSize],
    [centerLng + halfSize, centerLat + halfSize],
    [centerLng - halfSize, centerLat + halfSize],
  ];
  
  return '{"type": "Polygon", "coordinates": [$coordinates]}';
}
