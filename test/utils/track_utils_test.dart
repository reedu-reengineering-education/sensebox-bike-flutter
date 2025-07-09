import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/utils/track_utils.dart';

import '../mocks.dart';
import '../test_helpers.dart';

void main() {

  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/path_provider');

  late Isar isar;
  late IsarService isarService;
  late TrackData trackData;
  late GeolocationData geolocationData;
  late SensorData sensorData;
  late Directory tempDirectory;

  setUp(() async {
    initializeTestDependencies();

    // Create a temporary directory for testing
    tempDirectory = Directory.systemTemp.createTempSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDirectory.path;
      }
      return null;
    });

    isar = await initializeInMemoryIsar();
    // Mock IsarProvider to return the in-memory Isar instance
    final mockIsarProvider = MockIsarProvider();
    when(() => mockIsarProvider.getDatabase()).thenAnswer((_) async => isar);

    isarService = IsarService(isarProvider: mockIsarProvider);

    await clearIsarDatabase(isar);
  });

  tearDown(() async {
    await isar.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  group('calculateBounds', () {
    test('returns world bounds for empty list', () {
      final bounds = calculateBounds([]);
      expect(bounds.southwest.coordinates.lng, -180);
      expect(bounds.southwest.coordinates.lat, -90);
      expect(bounds.northeast.coordinates.lng, 180);
      expect(bounds.northeast.coordinates.lat, 90);
    });

    test('returns minDelta bounds for single point', () {
      final geo = GeolocationData()
        ..latitude= 10.0
        ..longitude= 20.0
        ..timestamp= DateTime(1970, 1, 1);
      final bounds = calculateBounds([geo], minDelta: 0.002);
      expect(bounds.southwest.coordinates.lat, closeTo(10.0 - 0.001, 1e-9));
      expect(bounds.northeast.coordinates.lat, closeTo(10.0 + 0.001, 1e-9));
      expect(bounds.southwest.coordinates.lng, closeTo(20.0 - 0.001, 1e-9));
      expect(bounds.northeast.coordinates.lng, closeTo(20.0 + 0.001, 1e-9));
    });

    test('returns correct bounds for two distinct points', () {
      final geo1 = GeolocationData()
        ..latitude= 10.0
        ..longitude= 20.0
        ..timestamp= DateTime(1970, 1, 1);
      final geo2 = GeolocationData()
        ..latitude= 11.0
        ..longitude= 21.0
        ..timestamp= DateTime(1970, 1, 1);
      final bounds = calculateBounds([geo1, geo2], minDelta: 0.002);

      expect(bounds.southwest.coordinates.lat, 10.0);
      expect(bounds.northeast.coordinates.lat, 11.0);
      expect(bounds.southwest.coordinates.lng, 20.0);
      expect(bounds.northeast.coordinates.lng, 21.0);
    });

    test('applies minDelta if points are very close', () {
      final geo1 = GeolocationData()
        ..latitude= 10.0
        ..longitude= 20.0
        ..timestamp= DateTime(1970, 1, 1);
      final geo2 = GeolocationData()
        ..latitude= 10.0005
        ..longitude= 20.0005
        ..timestamp= DateTime(1970, 1, 1);
      final bounds = calculateBounds([geo1, geo2]);
      
      expect(
        bounds.northeast.coordinates.lat - bounds.southwest.coordinates.lat,
        closeTo(0.002, 1e-9),
      );
      expect(
        bounds.northeast.coordinates.lng - bounds.southwest.coordinates.lng,
        closeTo(0.002, 1e-9),
      );
    });
  });
  group('sensorColorForValue', () {
    test('returns green for value at min', () {
      final color = sensorColorForValue(value: 10, min: 10, max: 20);
      expect(color, Colors.green);
    });

    test('returns red for value at max', () {
      final color = sensorColorForValue(value: 20, min: 10, max: 20);
      expect(color, Colors.red);
    });

    test('returns orange for value at midpoint', () {
      final color = sensorColorForValue(value: 15, min: 10, max: 20);
      // Compare color value as Color.lerp may not return exactly Colors.orange
      expect(color.value, Colors.orange.value);
    });

    test('returns grey if min and max are zero', () {
      final color = sensorColorForValue(value: 0, min: 0, max: 0);
      expect(color, Colors.grey);
    });
  });

  group('trackName', () {
    test('returns formatted start and end time from geolocations', () async {
      final track = createMockTrackData();
      await isar.writeTxn(() async {
        await isar.trackDatas.put(track);
      });

      final start = createMockGeolocationData(track);
      start.track.value = track;
      await isar.writeTxn(() async {
        await isar.geolocationDatas.put(start);
        await start.track.save();
      });
      final end = createMockGeolocationData(track);
      end.track.value = track;
      await isar.writeTxn(() async {
        await isar.geolocationDatas.put(end);
        await end.track.save();
      });

      final expected =
          '${DateFormat('dd-MM-yyyy HH:mm').format(start.timestamp)} - ${DateFormat('HH:mm').format(end.timestamp)}';
      expect(trackName(track), expected);
    });

    test('throws if geolocations is empty and no error message provided',
        () async {
      final track = createMockTrackData();
      await isar.writeTxn(() async {
        await isar.trackDatas.put(track);
      });

      expect(trackName(track), "No data available");
    });

    test('returns error message, if geolocations is empty', () async {
      final track = createMockTrackData();
      await isar.writeTxn(() async {
        await isar.trackDatas.put(track);
      });
      final errorMessage = "Custom error message";

      expect(trackName(track, errorMessage: errorMessage), errorMessage);
    });

    test(
        'returns formatted start and end time, if geolocations has only one element',
        () async {
      final track = createMockTrackData();
      await isar.writeTxn(() async {
        await isar.trackDatas.put(track);
      });

      geolocationData = createMockGeolocationData(track);
      geolocationData.track.value = track;
      await isar.writeTxn(() async {
        await isar.geolocationDatas.put(geolocationData);
        await geolocationData.track.save();
      });

      final expected =
          '${DateFormat('dd-MM-yyyy HH:mm').format(geolocationData.timestamp)} - ${DateFormat('HH:mm').format(geolocationData.timestamp)}';

      expect(trackName(track), expected);
    });
  });
}