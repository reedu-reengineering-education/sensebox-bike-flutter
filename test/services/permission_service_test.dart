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
    PermissionService.debugAlwaysLocationPermissionRequest = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = originalPlatform;
    PermissionService.debugAlwaysLocationPermissionRequest = null;
  });

  void mockLocationServicesEnabled({required bool enabled}) {
    when(() => mockGeolocator.isLocationServiceEnabled())
        .thenAnswer((_) async => enabled);
  }

  void mockCheckPermission(geo.LocationPermission permission) {
    when(() => mockGeolocator.checkPermission())
        .thenAnswer((_) async => permission);
  }

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

      test('throws when requireAlways and permission stays whileInUse', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);
        PermissionService.debugAlwaysLocationPermissionRequest = () async {};

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(requireAlways: true),
          throwsA(isA<LocationPermissionDenied>()),
        );
      });

      test('completes when requireAlways and whileInUse escalates to always', () async {
        mockLocationServicesEnabled(enabled: true);

        var checkCount = 0;
        when(() => mockGeolocator.checkPermission()).thenAnswer((_) async {
          checkCount++;
          if (checkCount == 1) {
            return geo.LocationPermission.whileInUse;
          }
          return geo.LocationPermission.always;
        });
        PermissionService.debugAlwaysLocationPermissionRequest = () async {};

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(requireAlways: true),
          completes,
        );
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

      test('completes when permission is whileInUse without escalating', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(),
          completes,
        );
      });

      test('completes when requireAlways and permission escalates from denied to always',
          () async {
        mockLocationServicesEnabled(enabled: true);

        var checkCount = 0;
        when(() => mockGeolocator.checkPermission()).thenAnswer((_) async {
          checkCount++;
          if (checkCount == 1) {
            return geo.LocationPermission.denied;
          }
          return geo.LocationPermission.always;
        });
        when(() => mockGeolocator.requestPermission())
            .thenAnswer((_) async => geo.LocationPermission.whileInUse);
        PermissionService.debugAlwaysLocationPermissionRequest = () async {};

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(requireAlways: true),
          completes,
        );
        verify(() => mockGeolocator.requestPermission()).called(1);
      });

      test('completes when requireAlways and existing whileInUse escalates to always', () async {
        mockLocationServicesEnabled(enabled: true);

        var checkCount = 0;
        when(() => mockGeolocator.checkPermission()).thenAnswer((_) async {
          checkCount++;
          if (checkCount == 1) {
            return geo.LocationPermission.whileInUse;
          }
          return geo.LocationPermission.always;
        });
        PermissionService.debugAlwaysLocationPermissionRequest = () async {};

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(requireAlways: true),
          completes,
        );
        verifyNever(() => mockGeolocator.requestPermission());
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

      test('throws when requireAlways and permission stays whileInUse', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);
        PermissionService.debugAlwaysLocationPermissionRequest = () async {};

        await expectLater(
          PermissionService.ensureLocationPermissionsGranted(requireAlways: true),
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

      test('returns true if permission is whileInUse by default', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);

        final result = await PermissionService.isLocationPermissionGranted();
        expect(result, isTrue);
      });

      test('returns false when requireAlways and permission stays whileInUse', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);
        PermissionService.debugAlwaysLocationPermissionRequest = () async {};

        final result = await PermissionService.isLocationPermissionGranted(
          requireAlways: true,
        );
        expect(result, isFalse);
      });

      test('returns true when requireAlways and whileInUse escalates to always', () async {
        mockLocationServicesEnabled(enabled: true);

        var checkCount = 0;
        when(() => mockGeolocator.checkPermission()).thenAnswer((_) async {
          checkCount++;
          if (checkCount == 1) {
            return geo.LocationPermission.whileInUse;
          }
          return geo.LocationPermission.always;
        });
        PermissionService.debugAlwaysLocationPermissionRequest = () async {};

        final result = await PermissionService.isLocationPermissionGranted(
          requireAlways: true,
        );
        expect(result, isTrue);
      });
    });

    group('on iOS', () {
      setUp(() {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      });

      test('returns true if permission is whileInUse by default', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);

        final result = await PermissionService.isLocationPermissionGranted();
        expect(result, isTrue);
      });

      test('returns true when requireAlways and whileInUse escalates to always', () async {
        mockLocationServicesEnabled(enabled: true);

        var checkCount = 0;
        when(() => mockGeolocator.checkPermission()).thenAnswer((_) async {
          checkCount++;
          if (checkCount == 1) {
            return geo.LocationPermission.whileInUse;
          }
          return geo.LocationPermission.always;
        });
        PermissionService.debugAlwaysLocationPermissionRequest = () async {};

        final result = await PermissionService.isLocationPermissionGranted(
          requireAlways: true,
        );
        expect(result, isTrue);
        verifyNever(() => mockGeolocator.requestPermission());
      });

      test('returns false when requireAlways and permission stays whileInUse', () async {
        mockLocationServicesEnabled(enabled: true);
        mockCheckPermission(geo.LocationPermission.whileInUse);
        PermissionService.debugAlwaysLocationPermissionRequest = () async {};

        final result = await PermissionService.isLocationPermissionGranted(
          requireAlways: true,
        );
        expect(result, isFalse);
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
