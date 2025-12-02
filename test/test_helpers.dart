import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:isar_community/isar.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initializes common test dependencies
void initializeTestDependencies() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences
  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    channel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      return null;
    },
  );

  // Ensure SharedPreferences is initialized
  SharedPreferences.setMockInitialValues({});
}

/// Creates a MaterialApp wrapper with localization support
Widget createLocalizedTestApp({
  required Widget child,
  required Locale locale,
  List<LocalizationsDelegate<dynamic>>? additionalDelegates,
}) {
  return MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      ...?additionalDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: child,
  );
}

/// Disables Provider debug checks
void disableProviderDebugChecks() {
  Provider.debugCheckInvalidValueType = null;
}

Future<void> tapElement(
    FinderBase<Element> element, WidgetTester tester) async {
  await tester.tap(element);
  await tester.pumpAndSettle();
}

Future<Isar> initializeInMemoryIsar() async {
  await Isar.initializeIsarCore(download: true);
  return await Isar.open(
    [TrackDataSchema, GeolocationDataSchema, SensorDataSchema],
    directory: '',
  );
}

void mockPathProvider(String tempDirectoryPath) {
  const MethodChannel pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  pathProviderChannel.setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return tempDirectoryPath;
    }
    return null;
  });
}

Future<void> clearIsarDatabase(Isar isar) async {
  await isar.writeTxn(() async {
    await isar.trackDatas.clear();
    await isar.geolocationDatas.clear();
    await isar.sensorDatas.clear();
  });
}

void mockSenseBoxInSharedPreferences() {
  final senseBox = SenseBox(
    name: 'Test SenseBox',
    grouptag: ['Sensor Group'],
    sensors: [
      Sensor(
        id: 'test-temp-sensor',
        title: 'Temperature',
        unit: '°C',
        sensorType: 'HDC1080',
        icon: 'osem-thermometer',
      ),
      Sensor(
        id: 'test-speed-sensor',
        title: 'Speed',
        unit: 'm/s',
        sensorType: 'GPS',
        icon: 'osem-dashboard',
      ),
    ],
  );

  SharedPreferences.setMockInitialValues(
    {'selectedSenseBox': jsonEncode(senseBox.toJson())},
  );
}

TrackData createMockTrackData() {
  return TrackData()
    ..id = Isar.autoIncrement;
}

GeolocationData createMockGeolocationData(TrackData trackData) {
  return GeolocationData()
    ..id = Isar.autoIncrement
    ..latitude = 52.5200
    ..longitude = 13.4050
    ..timestamp = DateTime.now()
    ..speed = 0.0
    ..track.value = trackData;
}

/// Creates a simple GeolocationData for coordinate testing
GeolocationData createTestGeolocation(double latitude, double longitude) {
  return GeolocationData()
    ..latitude = latitude
    ..longitude = longitude
    ..timestamp = DateTime.now()
    ..speed = 0.0;
}

SensorData createMockSensorData(GeolocationData geolocationData) {
  return SensorData()
    ..id = Isar.autoIncrement
    ..title = 'temperature'
    ..value = 25.0
    ..attribute = null
    ..characteristicUuid = '1234-5678-9012-3456'
    ..geolocationData.value = geolocationData;
}

/// Creates a square privacy zone GeoJSON string
/// [centerLat] - center latitude
/// [centerLng] - center longitude
/// [size] - size of the square (in degrees)
/// [closed] - whether to close the polygon (default: true)
String createSquarePrivacyZone(double centerLat, double centerLng, double size, {bool closed = true}) {
  final halfSize = size / 2;
  final coordinates = [
    [centerLng - halfSize, centerLat - halfSize],
    [centerLng + halfSize, centerLat - halfSize],
    [centerLng + halfSize, centerLat + halfSize],
    [centerLng - halfSize, centerLat + halfSize],
    if (closed) [centerLng - halfSize, centerLat - halfSize],
  ];
  
  final geoJson = {
    'type': 'Polygon',
    'coordinates': [coordinates],
  };
  
  return jsonEncode(geoJson);
}

/// Creates a polygon with many vertices (for testing complex polygons)
String createPolygonWithManyVertices(
    double centerLat, double centerLng, double size, int vertexCount) {
  final halfSize = size / 2;
  final coordinates = <List<double>>[];

  for (int i = 0; i < vertexCount; i++) {
    final angle = (2 * pi * i) / vertexCount;
    final lat = centerLat + halfSize * cos(angle);
    final lng = centerLng + halfSize * sin(angle);
    coordinates.add([lng, lat]);
  }

  coordinates.add(coordinates.first);

  final geoJson = {
    'type': 'Polygon',
    'coordinates': [coordinates],
  };

  return jsonEncode(geoJson);
}

/// Creates a privacy zone crossing the international date line
String createZoneCrossingDateLine() {
  final coordinates = [
    [179.9, 52.4],
    [-179.9, 52.4],
    [-179.9, 52.6],
    [179.9, 52.6],
    [179.9, 52.4],
  ];

  final geoJson = {
    'type': 'Polygon',
    'coordinates': [coordinates],
  };

  return jsonEncode(geoJson);
}

/// Creates a mock Position for testing
geo.Position createMockPosition(double lat, double lng, {DateTime? timestamp}) {
  return geo.Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: 1.0,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

/// Sets up a mock Geolocator to return a specific position
/// Requires MockGeolocator from mocks.dart
void setupMockGeolocator(dynamic mockGeolocator, double lat, double lng,
    {DateTime? timestamp}) {
  when(() => mockGeolocator.isLocationServiceEnabled())
      .thenAnswer((_) async => true);
  when(() => mockGeolocator.checkPermission())
      .thenAnswer((_) async => geo.LocationPermission.whileInUse);
  when(() => mockGeolocator.getCurrentPosition(
          locationSettings: any(named: 'locationSettings')))
      .thenAnswer(
          (_) async => createMockPosition(lat, lng, timestamp: timestamp));
}

/// Sets up recording mode for tests
/// Requires MockRecordingBloc and MockIsarService from mocks.dart
void setupRecordingMode(dynamic recordingBloc, dynamic isarService) {
  when(() => isarService.geolocationService.saveGeolocationData(any()))
      .thenAnswer((_) async => 1);
  recordingBloc.setRecording(true);
  when(() => recordingBloc.currentTrack).thenReturn(createMockTrackData());
}

/// Test constants for privacy zone tests
const double testLat1 = 52.5;
const double testLng1 = 13.4;
const double testLat2 = 53.0;
const double testLng2 = 14.0;
const double testLat3 = 54.0;
const double testLng3 = 15.0;
const double defaultZoneSize = 0.1;
const Duration shortDelay = Duration(milliseconds: 10);
const Duration mediumDelay = Duration(milliseconds: 50);

/// Helper function to test geolocation filtering with privacy zones
/// This function sets up privacy zones, mocks a position, and verifies emission/saving behavior
Future<void> testGeolocationWithPrivacyZone({
  required dynamic geolocationBloc,
  required StreamController<List<String>> privacyZonesController,
  required List<GeolocationData> emittedGeolocations,
  required dynamic mockGeolocator,
  required dynamic mockIsarService,
  required double lat,
  required double lng,
  required List<String> zones,
  required bool shouldEmit,
  required bool shouldSave,
}) async {
  privacyZonesController.add(zones);
  await Future.delayed(shortDelay);

  setupMockGeolocator(mockGeolocator, lat, lng);

  final initialCount = emittedGeolocations.length;
  await geolocationBloc.getCurrentLocationAndEmit();
  await Future.delayed(mediumDelay);

  if (shouldEmit) {
    expect(emittedGeolocations.length, greaterThan(initialCount));
  } else {
    expect(emittedGeolocations.length, initialCount);
  }

  if (shouldSave) {
    verify(() => mockIsarService.geolocationService.saveGeolocationData(any()))
        .called(1);
  } else {
    verifyNever(
        () => mockIsarService.geolocationService.saveGeolocationData(any()));
  }
}
