import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements geo.GeolocatorPlatform {}

void main() {
  late MockGeolocator mockGeolocator;
  final defaultTargetPlatformOverride = debugDefaultTargetPlatformOverride;

  setUp(() {
    mockGeolocator = MockGeolocator();
    geo.GeolocatorPlatform.instance = mockGeolocator;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = defaultTargetPlatformOverride;
  });

  group('PermissionService.ensureForegroundLocationPermissionsGranted', () {
    test('throws if location services are disabled', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      expect(
        () => PermissionService.ensureForegroundLocationPermissionsGranted(),
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
        () => PermissionService.ensureForegroundLocationPermissionsGranted(),
        throwsA(isA<LocationPermissionDenied>()),
      );
    });

    test('throws if permission is deniedForever', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.deniedForever);

      expect(
        () => PermissionService.ensureForegroundLocationPermissionsGranted(),
        throwsA(isA<LocationPermissionDenied>()),
      );
    });

    test('completes if permission is whileInUse on Android', () async {
      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);

      await expectLater(
        PermissionService.ensureForegroundLocationPermissionsGranted(),
        completes,
      );
    });

    test('completes if permission is whileInUse on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);

      await expectLater(
        PermissionService.ensureForegroundLocationPermissionsGranted(),
        completes,
      );
    });
  });

  group('PermissionService.ensureLocationPermissionsForRecording', () {
    test('completes on iOS when permission is always', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.always);

      await expectLater(
        PermissionService.ensureLocationPermissionsForRecording(),
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

    test('returns true for whileInUse on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.whileInUse);

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

  group('PermissionService.requestInitialLocationPermissionsIfNeeded', () {
    test('skips when initial permissions were already requested', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({
        SharedPreferencesKeys.initialLocationPermissionsRequestedAt:
            DateTime.now().toIso8601String(),
      });

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);

      await PermissionService.requestInitialLocationPermissionsIfNeeded();

      verifyNever(() => mockGeolocator.checkPermission());
    });

    test('records request on first call on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.always);

      await PermissionService.requestInitialLocationPermissionsIfNeeded();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(
            SharedPreferencesKeys.initialLocationPermissionsRequestedAt),
        isTrue,
      );
    });

    test('does not record request when user still has denied permission',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      when(() => mockGeolocator.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockGeolocator.checkPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);
      when(() => mockGeolocator.requestPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);

      await PermissionService.requestInitialLocationPermissionsIfNeeded();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(
            SharedPreferencesKeys.initialLocationPermissionsRequestedAt),
        isFalse,
      );
    });

    test('does nothing on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await PermissionService.requestInitialLocationPermissionsIfNeeded();

      verifyNever(() => mockGeolocator.isLocationServiceEnabled());
    });
  });
}
