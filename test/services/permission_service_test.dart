import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/permission_service.dart';

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

  void mockLocationServicesEnabled({required bool enabled}) {
    when(() => mockGeolocator.isLocationServiceEnabled())
        .thenAnswer((_) async => enabled);
  }

  void mockCheckPermission(geo.LocationPermission permission) {
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) async => permission);
  }

  group('isLocationAccessSufficient', () {
    test('requires always on iOS-like platforms', () {
      expect(
        isLocationAccessSufficient(
          geo.LocationPermission.always,
          requiresAlways: true,
        ),
        isTrue,
      );
      expect(
        isLocationAccessSufficient(
          geo.LocationPermission.whileInUse,
          requiresAlways: true,
        ),
        isFalse,
      );
    });

    test('accepts whileInUse on Android-like platforms', () {
      expect(
        isLocationAccessSufficient(
          geo.LocationPermission.whileInUse,
          requiresAlways: false,
        ),
        isTrue,
      );
      expect(
        isLocationAccessSufficient(
          geo.LocationPermission.always,
          requiresAlways: false,
        ),
        isTrue,
      );
      expect(
        isLocationAccessSufficient(
          geo.LocationPermission.denied,
          requiresAlways: false,
        ),
        isFalse,
      );
    });
  });

  group('PermissionService.ensureLocationPermissionsGranted', () {
    test('throws if location services are disabled', () async {
      mockLocationServicesEnabled(enabled: false);

      await expectLater(
        PermissionService.ensureLocationPermissionsGranted(),
        throwsA(isA<LocationPermissionDenied>()),
      );
    });

    test('throws if permission is denied after request', () async {
      mockLocationServicesEnabled(enabled: true);
      mockCheckPermission(geo.LocationPermission.denied);
      when(() => mockGeolocator.requestPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);

      await expectLater(
        PermissionService.ensureLocationPermissionsGranted(),
        throwsA(isA<LocationPermissionDenied>()),
      );
    });

    test('throws if permission is deniedForever without requesting again',
        () async {
      mockLocationServicesEnabled(enabled: true);
      mockCheckPermission(geo.LocationPermission.deniedForever);

      await expectLater(
        PermissionService.ensureLocationPermissionsGranted(),
        throwsA(isA<LocationPermissionDenied>()),
      );
      verifyNever(() => mockGeolocator.requestPermission());
    });

    group('on Android', () {
      setUp(() {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
      });

      test('completes when permission is whileInUse without requesting', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(),
          completes,
        );
        verifyNever(() => mockGeolocator.requestPermission());
      });

      test('completes when permission is always', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.always);

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(),
          completes,
        );
        verifyNever(() => mockGeolocator.requestPermission());
      });
    });

    group('on iOS', () {
      setUp(() {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      });

      test('completes when permission escalates from denied to always',
          () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.denied);

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

      test('completes when existing whileInUse escalates to always', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);
        when(() => mockGeolocator.requestPermission())
            .thenAnswer((_) async => geo.LocationPermission.always);

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(),
          completes,
        );
        verify(() => mockGeolocator.requestPermission()).called(1);
      });

      test('completes when permission is already always without requesting',
          () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.always);

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(),
          completes,
        );
        verifyNever(() => mockGeolocator.requestPermission());
      });

      test('throws when permission stays whileInUse', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);
        when(() => mockGeolocator.requestPermission())
            .thenAnswer((_) async => geo.LocationPermission.whileInUse);

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(),
          throwsA(isA<LocationPermissionDenied>()),
        );
      });
    });

    group('on macOS', () {
      setUp(() {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      });

      test('throws when permission stays whileInUse', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);
        when(() => mockGeolocator.requestPermission())
            .thenAnswer((_) async => geo.LocationPermission.whileInUse);

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(),
          throwsA(isA<LocationPermissionDenied>()),
        );
      });
    });
  });

  group('PermissionService.isLocationPermissionGranted', () {
    test('returns false if location services are disabled', () async {
      mockLocationServicesEnabled(enabled: false);

      final result = await PermissionService.isLocationPermissionGranted();
      expect(result, isFalse);
    });

    test('returns false if permission is deniedForever without requesting',
        () async {
      mockLocationServicesEnabled(enabled: true);
      mockCheckPermission(geo.LocationPermission.deniedForever);

      final result = await PermissionService.isLocationPermissionGranted();
      expect(result, isFalse);
      verifyNever(() => mockGeolocator.requestPermission());
    });

    group('on Android', () {
      setUp(() {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
      });

      test('returns true if permission is whileInUse', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);

        final result = await PermissionService.isLocationPermissionGranted();
        expect(result, isTrue);
        verifyNever(() => mockGeolocator.requestPermission());
      });
    });

    group('on iOS', () {
      setUp(() {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      });

      test('returns false if permission stays whileInUse', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);
        when(() => mockGeolocator.requestPermission())
            .thenAnswer((_) async => geo.LocationPermission.whileInUse);

        final result = await PermissionService.isLocationPermissionGranted();
        expect(result, isFalse);
      });

      test('returns true when whileInUse escalates to always', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);
        when(() => mockGeolocator.requestPermission())
            .thenAnswer((_) async => geo.LocationPermission.always);

        final result = await PermissionService.isLocationPermissionGranted();
        expect(result, isTrue);
        verify(() => mockGeolocator.requestPermission()).called(1);
      });

      test('returns true when permission is already always', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.always);

        final result = await PermissionService.isLocationPermissionGranted();
        expect(result, isTrue);
        verifyNever(() => mockGeolocator.requestPermission());
      });
    });

    test('returns false if permission is denied after request', () async {
      mockLocationServicesEnabled(enabled: true);
      mockCheckPermission(geo.LocationPermission.denied);
      when(() => mockGeolocator.requestPermission())
          .thenAnswer((_) async => geo.LocationPermission.denied);

      final result = await PermissionService.isLocationPermissionGranted();
      expect(result, isFalse);
    });
  });
}
