import 'dart:async';
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

      test('should subscribe to privacy zones stream on initialization',
          () async {
        final zone1 =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        privacyZonesController.add([zone1]);
        await Future.delayed(shortDelay);

        setupMockGeolocator(mockGeolocator, testLat1, testLng1);
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        expect(emittedGeolocations.length, 0);

        final zone2 =
            createSquarePrivacyZone(testLat2, testLng2, defaultZoneSize);
        privacyZonesController.add([zone2]);
        await Future.delayed(shortDelay);

        emittedGeolocations.clear();
        setupMockGeolocator(mockGeolocator, testLat1, testLng1);
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        expect(emittedGeolocations.length, 1);
      });
    });

    group('privacy zone filtering during recording', () {
      setUp(() {
        setupRecordingMode(mockRecordingBloc, mockIsarService);
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

      test('should emit and save geolocations outside privacy zone', () async {
        await testGeolocationWithPrivacyZone(
          geolocationBloc: geolocationBloc,
          privacyZonesController: privacyZonesController,
          emittedGeolocations: emittedGeolocations,
          mockGeolocator: mockGeolocator,
          mockIsarService: mockIsarService,
          lat: testLat2,
          lng: testLng2,
          zones: [createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize)],
          shouldEmit: true,
          shouldSave: true,
        );
      });

      test('should apply privacy zone updates during active recording',
          () async {
        final zone1 =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        privacyZonesController.add([zone1]);
        await Future.delayed(shortDelay);

        setupMockGeolocator(mockGeolocator, testLat1, testLng1);
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        expect(emittedGeolocations.length, 0);
        verifyNever(() =>
            mockIsarService.geolocationService.saveGeolocationData(any()));

        final zone2 =
            createSquarePrivacyZone(testLat2, testLng2, defaultZoneSize);
        privacyZonesController.add([zone2]);
        await Future.delayed(shortDelay);

        emittedGeolocations.clear();
        setupMockGeolocator(mockGeolocator, testLat1, testLng1);
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        expect(emittedGeolocations.length, 1);
        verify(() =>
                mockIsarService.geolocationService.saveGeolocationData(any()))
            .called(1);
      });
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

      test('should emit geolocations outside privacy zone when not recording',
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
          shouldEmit: true,
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

      test('should filter point inside any of multiple zones', () async {
        final zone1 =
            createSquarePrivacyZone(testLat1, testLng1, defaultZoneSize);
        final zone2 =
            createSquarePrivacyZone(testLat2, testLng2, defaultZoneSize);
        privacyZonesController.add([zone1, zone2]);
        await Future.delayed(shortDelay);

        setupMockGeolocator(mockGeolocator, testLat1, testLng1);
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        expect(emittedGeolocations.length, 0);

        emittedGeolocations.clear();
        setupMockGeolocator(mockGeolocator, testLat2, testLng2);
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        expect(emittedGeolocations.length, 0);

        emittedGeolocations.clear();
        setupMockGeolocator(mockGeolocator, testLat3, testLng3);
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(mediumDelay);

        expect(emittedGeolocations.length, 1);
      });
    });
  });
}
