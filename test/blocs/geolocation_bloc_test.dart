import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import '../mocks.dart';
import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeolocationBloc Privacy Zone Filtering', () {
    late GeolocationBloc geolocationBloc;
    late MockIsarService mockIsarService;
    late MockRecordingBloc mockRecordingBloc;
    late MockSettingsBloc mockSettingsBloc;
    late StreamController<List<String>> privacyZonesController;
    late List<GeolocationData> emittedGeolocations;
    late MockGeolocator mockGeolocator;

    setUp(() {
      mockIsarService = MockIsarService();
      mockRecordingBloc = MockRecordingBloc();
      mockSettingsBloc = MockSettingsBloc();
      privacyZonesController = StreamController<List<String>>.broadcast();
      emittedGeolocations = [];
      mockGeolocator = MockGeolocator();
      geo.GeolocatorPlatform.instance = mockGeolocator;

      when(() => mockSettingsBloc.privacyZones).thenReturn([]);
      when(() => mockSettingsBloc.privacyZonesStream)
          .thenAnswer((_) => privacyZonesController.stream);

      geolocationBloc = GeolocationBloc(
        mockIsarService,
        mockRecordingBloc,
        mockSettingsBloc,
      );

      geolocationBloc.geolocationStream.listen((geo) {
        emittedGeolocations.add(geo);
      });
    });

    tearDown(() {
      privacyZonesController.close();
      geolocationBloc.dispose();
      emittedGeolocations.clear();
    });

    group('privacy zone initialization', () {
      test('should initialize with current privacy zones from settings', () {
        final zoneJson =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        when(() => mockSettingsBloc.privacyZones).thenReturn([zoneJson]);

        final newBloc = GeolocationBloc(
          mockIsarService,
          mockRecordingBloc,
          mockSettingsBloc,
        );

        expect(newBloc.geolocationStream, isNotNull);
        newBloc.dispose();
      });

      // TODO: Fix test isolation issue with _lastEmittedPosition persisting between tests
      // test('should subscribe to privacy zones stream on initialization',
      //     () async {
      //   setupRecordingMode(mockRecordingBloc, mockIsarService);
      //   geolocationBloc.stopListening();
      //
      //   final zone1 =
      //       createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
      //   privacyZonesController.add([zone1]);
      //   await Future.delayed(shortDelay);
      //
      //   final firstTimestamp = DateTime.now().toUtc();
      //   setupMockGeolocator(mockGeolocator, testLat1, testLng1,
      //       timestamp: firstTimestamp);
      //   await geolocationBloc.getCurrentLocationAndEmit();
      //   await Future.delayed(mediumDelay);
      //
      //   expect(emittedGeolocations.length, 0);
      //
      //   final zone2 =
      //       createSquarePrivacyZone(testLat2, testLng2, defaultZoneSize);
      //   privacyZonesController.add([zone2]);
      //   await Future.delayed(shortDelay);
      //
      //   emittedGeolocations.clear();
      //   final secondTimestamp =
      //       DateTime.now().toUtc().add(const Duration(seconds: 10));
      //   setupMockGeolocator(mockGeolocator, testLat1, testLng1,
      //       timestamp: secondTimestamp);
      //   await geolocationBloc.getCurrentLocationAndEmit();
      //   await Future.delayed(mediumDelay);
      //
      //   expect(emittedGeolocations.length, 1);
      //   verify(() =>
      //           mockIsarService.geolocationService.saveGeolocationData(any()))
      //       .called(1);
      // });
    });

    group('privacy zone filtering during recording', () {
      setUp(() {
        setupRecordingMode(mockRecordingBloc, mockIsarService);
      });
      
      tearDown(() {
        geolocationBloc.stopListening();
      });

      test('should not emit geolocations inside privacy zone', () async {
        await testGeolocationWithPrivacyZone(
          geolocationBloc: geolocationBloc,
          privacyZonesController: privacyZonesController,
          emittedGeolocations: emittedGeolocations,
          mockGeolocator: mockGeolocator,
          mockIsarService: mockIsarService,
          lat: testLat1,
          lng: testLng1,
          zones: [createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize)],
          shouldEmit: false,
          shouldSave: false,
        );
      });

      // TODO: Fix test isolation issue with _lastEmittedPosition persisting between tests
      // test('should emit and save geolocations outside privacy zone', () async {
      //   await testGeolocationWithPrivacyZone(
      //     geolocationBloc: geolocationBloc,
      //     privacyZonesController: privacyZonesController,
      //     emittedGeolocations: emittedGeolocations,
      //     mockGeolocator: mockGeolocator,
      //     mockIsarService: mockIsarService,
      //     lat: testLat2,
      //     lng: testLng2,
      //     zones: [createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize)],
      //     shouldEmit: true,
      //     shouldSave: true,
      //   );
      // });

      // TODO: Fix test isolation issue with _lastEmittedPosition persisting between tests
      // test('should apply privacy zone updates during active recording',
      //     () async {
      //   geolocationBloc.stopListening();
      //
      //   final zone1 =
      //       createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
      //   privacyZonesController.add([zone1]);
      //   await Future.delayed(shortDelay);
      //
      //   setupMockGeolocator(mockGeolocator, testLat1, testLng1);
      //   await geolocationBloc.getCurrentLocationAndEmit();
      //   await Future.delayed(mediumDelay);
      //
      //   expect(emittedGeolocations.length, 0);
      //   verifyNever(() =>
      //       mockIsarService.geolocationService.saveGeolocationData(any()));
      //
      //   final zone2 =
      //       createSquarePrivacyZone(testLat2, testLng2, defaultZoneSize);
      //   privacyZonesController.add([zone2]);
      //   await Future.delayed(shortDelay);
      //
      //   emittedGeolocations.clear();
      //   final secondTimestamp =
      //       DateTime.now().toUtc().add(const Duration(seconds: 10));
      //   setupMockGeolocator(mockGeolocator, testLat1, testLng1,
      //       timestamp: secondTimestamp);
      //   await geolocationBloc.getCurrentLocationAndEmit();
      //   await Future.delayed(mediumDelay);
      //
      //   expect(emittedGeolocations.length, 1);
      //   verify(() =>
      //           mockIsarService.geolocationService.saveGeolocationData(any()))
      //       .called(1);
      // });
    });

    group('privacy zone filtering when not recording', () {
      test('should filter privacy zones even when not recording', () async {
        await testGeolocationWithPrivacyZone(
          geolocationBloc: geolocationBloc,
          privacyZonesController: privacyZonesController,
          emittedGeolocations: emittedGeolocations,
          mockGeolocator: mockGeolocator,
          mockIsarService: mockIsarService,
          lat: testLat1,
          lng: testLng1,
          zones: [createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize)],
          shouldEmit: false,
          shouldSave: false,
        );
      });

      test(
          'should not emit geolocations when not recording even if outside privacy zone',
          () async {
        await testGeolocationWithPrivacyZone(
          geolocationBloc: geolocationBloc,
          privacyZonesController: privacyZonesController,
          emittedGeolocations: emittedGeolocations,
          mockGeolocator: mockGeolocator,
          mockIsarService: mockIsarService,
          lat: testLat2,
          lng: testLng2,
          zones: [createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize)],
          shouldEmit: false,
          shouldSave: false,
        );
      });
    });

    group('duplicate geolocation filtering with privacy zones', () {
      setUp(() {
        setupRecordingMode(mockRecordingBloc, mockIsarService);
      });

      test('should skip duplicate geolocations even if outside privacy zone',
          () async {
        final zoneJson =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        privacyZonesController.add([zoneJson]);
        await Future.delayed(shortDelay);

        final now = DateTime.now();
        setupMockGeolocator(mockGeolocator, testLat2, testLng2, timestamp: now);

        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        emittedGeolocations.clear();

        setupMockGeolocator(mockGeolocator, testLat2, testLng2, timestamp: now);
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        expect(emittedGeolocations.length, 0);
      });

      test('should handle privacy zone check before duplicate check', () async {
        final zoneJson =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        privacyZonesController.add([zoneJson]);
        await Future.delayed(shortDelay);

        final now = DateTime.now();
        setupMockGeolocator(mockGeolocator, testLat1, testLng1, timestamp: now);

        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        setupMockGeolocator(mockGeolocator, testLat1, testLng1, timestamp: now);
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        expect(emittedGeolocations.length, 0);
        verifyNever(() =>
            mockIsarService.geolocationService.saveGeolocationData(any()));
      });
    });

    group('multiple privacy zones', () {
      setUp(() {
        setupRecordingMode(mockRecordingBloc, mockIsarService);
      });
      
      tearDown(() {
        geolocationBloc.stopListening();
      });

      // TODO: Fix test isolation issue with _lastEmittedPosition persisting between tests
      // test('should filter point inside any of multiple zones', () async {
      //   final zone1 =
      //       createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
      //   final zone2 =
      //       createSquarePrivacyZone(testLat2, testLng2, defaultZoneSize);
      //   privacyZonesController.add([zone1, zone2]);
      //   await Future.delayed(shortDelay);
      //
      //   final firstTimestamp = DateTime.now().toUtc();
      //   setupMockGeolocator(mockGeolocator, testLat1, testLng1,
      //       timestamp: firstTimestamp);
      //   await geolocationBloc.getCurrentLocationAndEmit();
      //   await Future.delayed(mediumDelay);
      //
      //   expect(emittedGeolocations.length, 0);
      //
      //   emittedGeolocations.clear();
      //   final secondTimestamp =
      //       DateTime.now().toUtc().add(const Duration(seconds: 10));
      //   setupMockGeolocator(mockGeolocator, testLat2, testLng2,
      //       timestamp: secondTimestamp);
      //   await geolocationBloc.getCurrentLocationAndEmit();
      //   await Future.delayed(mediumDelay);
      //
      //   expect(emittedGeolocations.length, 0);
      //
      //   emittedGeolocations.clear();
      //   final thirdTimestamp =
      //       DateTime.now().toUtc().add(const Duration(seconds: 20));
      //   setupMockGeolocator(mockGeolocator, testLat3, testLng3,
      //       timestamp: thirdTimestamp);
      //   await geolocationBloc.getCurrentLocationAndEmit();
      //   await Future.delayed(mediumDelay);
      //
      //   expect(emittedGeolocations.length, 1);
      // });
    });
  });

  group('GeolocationBloc.shouldSkipGeolocation', () {
    late GeolocationBloc geolocationBloc;
    late MockIsarService mockIsarService;
    late MockRecordingBloc mockRecordingBloc;
    late MockSettingsBloc mockSettingsBloc;
    late StreamController<List<String>> privacyZonesController;
    late MockGeolocator mockGeolocator;

    setUp(() {
      mockIsarService = MockIsarService();
      mockRecordingBloc = MockRecordingBloc();
      mockSettingsBloc = MockSettingsBloc();
      privacyZonesController = StreamController<List<String>>.broadcast();
      mockGeolocator = MockGeolocator();
      geo.GeolocatorPlatform.instance = mockGeolocator;

      when(() => mockSettingsBloc.privacyZones).thenReturn([]);
      when(() => mockSettingsBloc.privacyZonesStream)
          .thenAnswer((_) => privacyZonesController.stream);

      geolocationBloc = GeolocationBloc(
        mockIsarService,
        mockRecordingBloc,
        mockSettingsBloc,
      );
    });

    tearDown(() {
      privacyZonesController.close();
      geolocationBloc.dispose();
    });

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

    group('when lastEmittedPosition is null', () {
      test('should skip if geolocation is in privacy zone', () async {
        final zoneJson =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        privacyZonesController.add([zoneJson]);
        await Future.delayed(shortDelay);

        final geolocation = createGeolocation(
          latitude: testLat1,
          longitude: testLng1,
        );

        final result = geolocationBloc.shouldSkipGeolocation(geolocation);

        expect(result, true);
      });

      test('should not skip if geolocation is outside privacy zone', () {
        final zoneJson =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        privacyZonesController.add([zoneJson]);

        final geolocation = createGeolocation(
          latitude: testLat2,
          longitude: testLng2,
        );

        final result = geolocationBloc.shouldSkipGeolocation(geolocation);

        expect(result, false);
      });
    });

    group('duplicate timestamp filtering', () {
      test('should skip if timestamps are identical', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(timestamp: now);

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, true);
      });

      test('should not skip if timestamps differ', () {
        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(seconds: 10)),
        );

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, false);
      });
    });

    group('iOS platform - 1 second interval enforcement', () {
      test('should skip if less than 1 second has passed', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(milliseconds: 500)),
        );

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, true);

        debugDefaultTargetPlatformOverride = null;
      });

      test('should not skip if 1 or more seconds have passed', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(seconds: 1)),
        );

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, false);

        debugDefaultTargetPlatformOverride = null;
      });

      test('should skip if exactly 0.999 seconds have passed', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(milliseconds: 999)),
        );

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, true);

        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Android platform - 1 second interval enforcement', () {
      test('should skip if less than 1 second has passed', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(
          timestamp: now,
          latitude: 52.5200,
          longitude: 13.4050,
        );
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(milliseconds: 500)),
          latitude: 52.5210,
          longitude: 13.4060,
        );

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, true);

        debugDefaultTargetPlatformOverride = null;
      });

      test('should not skip if 1 or more seconds have passed', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(
          timestamp: now,
          latitude: 52.5200,
          longitude: 13.4050,
        );
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(seconds: 1)),
          latitude: 52.5210,
          longitude: 13.4060,
        );

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, false);

        debugDefaultTargetPlatformOverride = null;
      });

      test('should skip if exactly 0.999 seconds have passed', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(milliseconds: 999)),
        );

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, true);

        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('privacy zone filtering with lastEmittedPosition', () {
      test('should skip if geolocation is in privacy zone', () async {
        final zoneJson =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        privacyZonesController.add([zoneJson]);
        await Future.delayed(shortDelay);

        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(
          timestamp: now.subtract(const Duration(seconds: 10)),
          latitude: testLat2,
          longitude: testLng2,
        );
        final currentPosition = createGeolocation(
          timestamp: now,
          latitude: testLat1,
          longitude: testLng1,
        );

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, true);
      });

      test('should not skip if geolocation is outside privacy zone', () async {
        final zoneJson =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        privacyZonesController.add([zoneJson]);
        await Future.delayed(shortDelay);

        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(
          timestamp: now.subtract(const Duration(seconds: 10)),
          latitude: testLat2,
          longitude: testLng2,
        );
        final currentPosition = createGeolocation(
          timestamp: now,
          latitude: testLat2,
          longitude: testLng2,
        );

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, false);
      });
    });

    group('macOS platform - same as iOS', () {
      test('should skip if less than 1 second has passed', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        final now = DateTime.now().toUtc();
        final lastPosition = createGeolocation(timestamp: now);
        final currentPosition = createGeolocation(
          timestamp: now.add(const Duration(milliseconds: 500)),
        );

        final result = geolocationBloc.shouldSkipGeolocation(
          currentPosition,
          lastEmittedPosition: lastPosition,
        );

        expect(result, true);

        debugDefaultTargetPlatformOverride = null;
      });
    });
  });
}
