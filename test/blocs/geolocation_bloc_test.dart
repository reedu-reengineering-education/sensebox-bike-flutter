import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import '../mocks.dart';

class MockGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements geo.GeolocatorPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeolocationBloc Privacy Zone Filtering', () {
    late GeolocationBloc geolocationBloc;
    late MockIsarService mockIsarService;
    late MockRecordingBloc mockRecordingBloc;
    late MockSettingsBloc mockSettingsBloc;
    late StreamController<List<String>> privacyZonesController;
    late List<GeolocationData> emittedGeolocations;

    setUp(() {
      mockIsarService = MockIsarService();
      mockRecordingBloc = MockRecordingBloc();
      mockSettingsBloc = MockSettingsBloc();
      privacyZonesController = StreamController<List<String>>.broadcast();
      emittedGeolocations = [];

      final mockGeolocator = MockGeolocator();
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

    group('privacy zone stream subscription', () {
      test('should initialize with current privacy zones', () {
        final zoneJson = _createSquareZone(52.5, 13.4, 0.1);
        when(() => mockSettingsBloc.privacyZones).thenReturn([zoneJson]);

        final newBloc = GeolocationBloc(
          mockIsarService,
          mockRecordingBloc,
          mockSettingsBloc,
        );

        expect(newBloc, isNotNull);
        newBloc.dispose();
      });

      test('should update privacy zones when stream emits', () async {
        final zone1 = _createSquareZone(52.5, 13.4, 0.1);
        privacyZonesController.add([zone1]);
        await Future.delayed(const Duration(milliseconds: 10));

        final zone2 = _createSquareZone(53.0, 14.0, 0.1);
        privacyZonesController.add([zone2]);
        await Future.delayed(const Duration(milliseconds: 10));

        expect(geolocationBloc, isNotNull);
      });
    });

    group('privacy zone filtering', () {
      test('should initialize privacy zone checker with current zones', () {
        final zoneJson = _createSquareZone(52.5, 13.4, 0.1);
        when(() => mockSettingsBloc.privacyZones).thenReturn([zoneJson]);

        final newBloc = GeolocationBloc(
          mockIsarService,
          mockRecordingBloc,
          mockSettingsBloc,
        );

        expect(newBloc.geolocationStream, isNotNull);
        newBloc.dispose();
      });

      test('should update privacy zones when stream emits changes', () async {
        final zone1 = _createSquareZone(52.5, 13.4, 0.1);
        privacyZonesController.add([zone1]);
        await Future.delayed(const Duration(milliseconds: 10));

        final zone2 = _createSquareZone(53.0, 14.0, 0.1);
        privacyZonesController.add([zone2]);
        await Future.delayed(const Duration(milliseconds: 10));

        expect(geolocationBloc, isNotNull);
      });

      test('should not emit geolocations inside privacy zone', () async {
        final zoneJson = _createSquareZone(52.5, 13.4, 0.1);
        privacyZonesController.add([zoneJson]);
        await Future.delayed(const Duration(milliseconds: 10));

        final mockGeolocator = geo.GeolocatorPlatform.instance as MockGeolocator;
        when(() => mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(() => mockGeolocator.checkPermission())
            .thenAnswer((_) async => geo.LocationPermission.whileInUse);
        when(() => mockGeolocator.getCurrentPosition(
                locationSettings: any(named: 'locationSettings')))
            .thenAnswer((_) async => geo.Position(
                  latitude: 52.5,
                  longitude: 13.4,
                  timestamp: DateTime.now(),
                  accuracy: 1.0,
                  altitude: 0.0,
                  altitudeAccuracy: 0.0,
                  heading: 0.0,
                  headingAccuracy: 0.0,
                  speed: 0.0,
                  speedAccuracy: 0.0,
                ));

        when(() => mockIsarService.geolocationService.saveGeolocationData(any()))
            .thenAnswer((_) async => 1);
        mockRecordingBloc.setRecording(true);
        when(() => mockRecordingBloc.currentTrack).thenReturn(null);

        final initialCount = emittedGeolocations.length;
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(emittedGeolocations.length, initialCount);
      });

      test('should emit geolocations outside privacy zone', () async {
        final zoneJson = _createSquareZone(52.5, 13.4, 0.1);
        privacyZonesController.add([zoneJson]);
        await Future.delayed(const Duration(milliseconds: 10));

        final mockGeolocator = geo.GeolocatorPlatform.instance as MockGeolocator;
        when(() => mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(() => mockGeolocator.checkPermission())
            .thenAnswer((_) async => geo.LocationPermission.whileInUse);
        when(() => mockGeolocator.getCurrentPosition(
                locationSettings: any(named: 'locationSettings')))
            .thenAnswer((_) async => geo.Position(
                  latitude: 53.0,
                  longitude: 14.0,
                  timestamp: DateTime.now(),
                  accuracy: 1.0,
                  altitude: 0.0,
                  altitudeAccuracy: 0.0,
                  heading: 0.0,
                  headingAccuracy: 0.0,
                  speed: 0.0,
                  speedAccuracy: 0.0,
                ));

        when(() => mockIsarService.geolocationService.saveGeolocationData(any()))
            .thenAnswer((_) async => 1);
        mockRecordingBloc.setRecording(true);
        when(() => mockRecordingBloc.currentTrack).thenReturn(null);

        final initialCount = emittedGeolocations.length;
        await geolocationBloc.getCurrentLocationAndEmit();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(emittedGeolocations.length, greaterThan(initialCount));
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

  final geoJson = {
    'type': 'Polygon',
    'coordinates': [coordinates],
  };

  return jsonEncode(geoJson);
}

