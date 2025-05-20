import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements geo.GeolocatorPlatform {}

void main() {
  late MockGeolocator mockGeolocator;

  setUp(() {
    mockGeolocator = MockGeolocator();
    geo.GeolocatorPlatform.instance = mockGeolocator;
  });

  group('PermissionService.ensureLocationPermissionsGranted', () {
    test('throws if location services are disabled', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      expect(
        () => PermissionService.ensureLocationPermissionsGranted(),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Location services are disabled.'))),
      );
    });

    test('throws if permission is denied after request', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);
      when(() => mockGeolocator.requestPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);

      expect(
        () => PermissionService.ensureLocationPermissionsGranted(),
        throwsA(isA<LocationPermissionDenied>()),
      );
    });

    test('throws if permission is deniedForever', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.deniedForever);

      expect(
        () => PermissionService.ensureLocationPermissionsGranted(),
        throwsA(isA<LocationPermissionDenied>()),
      );
    });

    test('completes if permission is granted', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);

      await expectLater(
        PermissionService.ensureLocationPermissionsGranted(),
        completes,
      );
    });
  });

  group('PermissionService.isLocationPermissionGranted', () {
    test('returns false if location services are disabled', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      final result = await PermissionService.isLocationPermissionGranted();
      expect(result, isFalse);
    });

    test('returns true if permission is whileInUse', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);

      final result = await PermissionService.isLocationPermissionGranted();
      expect(result, isTrue);
    });

    test('returns true if permission is always', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.always);

      final result = await PermissionService.isLocationPermissionGranted();
      expect(result, isTrue);
    });

    test('returns false if permission is denied after request', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);
      when(() => mockGeolocator.requestPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);

      final result = await PermissionService.isLocationPermissionGranted();
      expect(result, isFalse);
    });
  });
}