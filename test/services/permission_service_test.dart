import 'package:flutter/foundation.dart';
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
  late TargetPlatform? originalPlatform;

  setUp(() {
    mockGeolocator = MockGeolocator();
    geo.GeolocatorPlatform.instance = mockGeolocator;
    originalPlatform = debugDefaultTargetPlatformOverride;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = originalPlatform;
  });

  group('PermissionService.ensureLocationPermissionsGranted', () {
    test('throws if location services are disabled', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      expect(
        () => PermissionService.ensureLocationPermissionsGranted(),
        throwsA(isA<LocationPermissionDenied>()),
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

    test('completes on Android when permission is whileInUse', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);

      await expectLater(
        PermissionService.ensureLocationPermissionsGranted(),
        completes,
      );
    });

    test('completes on iOS when permission escalates to always', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);

      var requestCount = 0;
      when(() => mockGeolocator.requestPermission()).thenAnswer((_) async {
        requestCount++;
        if (requestCount == 1) {
          return geo.LocationPermission.whileInUse;
        }
        return geo.LocationPermission.always;
      });

      await expectLater(
        PermissionService.ensureLocationPermissionsGranted(),
        completes,
      );
      verify(() => mockGeolocator.requestPermission()).called(2);
    });

    test('throws on iOS when permission stays whileInUse', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);
      when(() => mockGeolocator.requestPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);

      expect(
        () => PermissionService.ensureLocationPermissionsGranted(),
        throwsA(isA<LocationPermissionDenied>()),
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

    test('returns true on Android if permission is whileInUse', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);

      final result = await PermissionService.isLocationPermissionGranted();
      expect(result, isTrue);
    });

    test('returns false on iOS if permission is whileInUse', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);
      when(() => mockGeolocator.requestPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);

      final result = await PermissionService.isLocationPermissionGranted();
      expect(result, isFalse);
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
