import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

void main() {
  late Isar isar;
  late TrackData trackData;

  setUp(() async {
    // Initialize in-memory Isar database
    await Isar.initializeIsarCore(download: true);
    isar = await Isar.open(
      [TrackDataSchema, GeolocationDataSchema, SensorDataSchema],
      directory: ''
    );

    trackData = TrackData();
    await isar.writeTxn(() async {
      await isar.trackDatas.put(trackData);
    });
  });

  tearDown(() async {
    await isar.close();
  });

  test('encodedPolyline returns empty string for empty geolocations', () async {
    expect(trackData.encodedPolyline, equals(""));
  });

  test('encodedPolyline handles single point correctly', () async {
    final geolocation = GeolocationData()
      ..latitude = 52.5200
      ..longitude = 13.4050
      ..timestamp = DateTime.now().toUtc()
      ..speed = 0.0;

    await isar.writeTxn(() async {
      trackData.geolocations.add(geolocation);
      await isar.geolocationDatas.put(geolocation);
    });

    final polyline = trackData.encodedPolyline;
    expect(polyline.isNotEmpty, isTrue);

    // Verify that the polyline contains two points (single point + offset)
    final decodedPolyline = decodePolyline(polyline);
    expect(decodedPolyline.length, equals(2));
  });

  test('encodedPolyline handles short tracks without simplification', () async {
    await isar.writeTxn(() async {
      for (int i = 0; i < 5; i++) {
        final geolocation = GeolocationData()
          ..latitude = 52.5200 + i * 0.001
          ..longitude = 13.4050 + i * 0.001
          ..timestamp = DateTime.now().toUtc().add(Duration(seconds: i))
          ..speed = 0.0;
        trackData.geolocations.add(geolocation);
        await isar.geolocationDatas.put(geolocation);
      }
    });

    final polyline = trackData.encodedPolyline;
    expect(polyline.isNotEmpty, isTrue);

    // Verify that the polyline contains all points
    final decodedPolyline = decodePolyline(polyline);
    expect(decodedPolyline.length, equals(5));
  });

  test('encodedPolyline simplifies long tracks dynamically', () async {
    await isar.writeTxn(() async {
      for (int i = 0; i < 20; i++) {
        final geolocation = GeolocationData()
          ..latitude = 52.5200 + i * 0.001
          ..longitude = 13.4050 + i * 0.001
          ..timestamp = DateTime.now().toUtc().add(Duration(seconds: i))
          ..speed = 0.0;
        trackData.geolocations.add(geolocation);
        await isar.geolocationDatas.put(geolocation);
      }
    });

    final polyline = trackData.encodedPolyline;
    expect(polyline.isNotEmpty, isTrue);

    // Verify that the polyline is simplified
    final decodedPolyline = decodePolyline(polyline);
    expect(decodedPolyline.length, lessThan(20));
  });

  test('calculateTolerance scales dynamically with number of coordinates', () {
    final toleranceSmall = trackData.calculateTolerance(10);
    final toleranceLarge = trackData.calculateTolerance(1000);

    expect(toleranceSmall, lessThan(toleranceLarge));
  });

  group('Upload tracking properties', () {
    test('new TrackData has default upload tracking values', () {
      final newTrack = TrackData();
      
      expect(newTrack.uploaded, isFalse);
      expect(newTrack.uploadAttempts, equals(0));
      expect(newTrack.lastUploadAttempt, isNull);
    });

    test('upload tracking properties can be set and retrieved', () async {
      final testDate = DateTime.now().toUtc();
      
      await isar.writeTxn(() async {
        trackData.uploaded = true;
        trackData.uploadAttempts = 3;
        trackData.lastUploadAttempt = testDate;
        await isar.trackDatas.put(trackData);
      });

      // Reload from database to verify persistence
      final reloadedTrack = await isar.trackDatas.get(trackData.id);
      
      expect(reloadedTrack!.uploaded, isTrue);
      expect(reloadedTrack.uploadAttempts, equals(3));
      // Compare timestamps with millisecond precision to avoid timezone issues
      expect(reloadedTrack.lastUploadAttempt?.millisecondsSinceEpoch, 
             equals(testDate.millisecondsSinceEpoch));
    });

    test('upload tracking properties persist across database operations', () async {
      final testDate = DateTime.now().toUtc();
      
      // Set upload tracking properties
      await isar.writeTxn(() async {
        trackData.uploaded = true;
        trackData.uploadAttempts = 5;
        trackData.lastUploadAttempt = testDate;
        await isar.trackDatas.put(trackData);
      });

      // Close and reopen database to test persistence
      await isar.close();
      
      isar = await Isar.open(
        [TrackDataSchema, GeolocationDataSchema, SensorDataSchema],
        directory: ''
      );

      final persistedTrack = await isar.trackDatas.get(trackData.id);
      
      expect(persistedTrack!.uploaded, isTrue);
      expect(persistedTrack.uploadAttempts, equals(5));
      // Compare timestamps with millisecond precision to avoid timezone issues
      expect(persistedTrack.lastUploadAttempt?.millisecondsSinceEpoch, 
             equals(testDate.millisecondsSinceEpoch));
    });

    test('can query tracks by upload status', () async {
      // Clear existing tracks to avoid interference
      await isar.writeTxn(() async {
        await isar.trackDatas.clear();
      });

      // Create multiple tracks with different upload statuses
      final uploadedTrack = TrackData()..uploaded = true;
      final notUploadedTrack1 = TrackData()..uploaded = false;
      final notUploadedTrack2 = TrackData()..uploaded = false;

      await isar.writeTxn(() async {
        await isar.trackDatas.putAll([uploadedTrack, notUploadedTrack1, notUploadedTrack2]);
      });

      // Query uploaded tracks
      final uploadedTracks = await isar.trackDatas
          .filter()
          .uploadedEqualTo(true)
          .findAll();
      
      expect(uploadedTracks.length, equals(1));
      expect(uploadedTracks.first.id, equals(uploadedTrack.id));

      // Query not uploaded tracks
      final notUploadedTracks = await isar.trackDatas
          .filter()
          .uploadedEqualTo(false)
          .findAll();
      
      expect(notUploadedTracks.length, equals(2));
    });

    test('can query tracks by upload attempts', () async {
      // Clear existing tracks to avoid interference
      await isar.writeTxn(() async {
        await isar.trackDatas.clear();
      });

      // Create tracks with different upload attempt counts
      final track1 = TrackData()..uploadAttempts = 0;
      final track2 = TrackData()..uploadAttempts = 3;
      final track3 = TrackData()..uploadAttempts = 5;

      await isar.writeTxn(() async {
        await isar.trackDatas.putAll([track1, track2, track3]);
      });

      // Query tracks with more than 2 upload attempts
      final retriedTracks = await isar.trackDatas
          .filter()
          .uploadAttemptsGreaterThan(2)
          .findAll();
      
      expect(retriedTracks.length, equals(2));
      expect(retriedTracks.map((t) => t.uploadAttempts), containsAll([3, 5]));
    });

    test('can sort tracks by last upload attempt', () async {
      // Clear existing tracks to avoid interference
      await isar.writeTxn(() async {
        await isar.trackDatas.clear();
      });

      final now = DateTime.now().toUtc();
      final track1 = TrackData()..lastUploadAttempt = now.subtract(Duration(hours: 2));
      final track2 = TrackData()..lastUploadAttempt = now.subtract(Duration(hours: 1));
      final track3 = TrackData()..lastUploadAttempt = now;

      await isar.writeTxn(() async {
        await isar.trackDatas.putAll([track1, track2, track3]);
      });

      // Query tracks sorted by last upload attempt (ascending)
      final sortedTracks = await isar.trackDatas
          .filter()
          .lastUploadAttemptIsNotNull()
          .sortByLastUploadAttempt()
          .findAll();
      
      expect(sortedTracks.length, equals(3));
      expect(sortedTracks[0].id, equals(track1.id));
      expect(sortedTracks[1].id, equals(track2.id));
      expect(sortedTracks[2].id, equals(track3.id));
    });

    test('backward compatibility - existing tracks get default values', () async {
      // This test simulates existing data that doesn't have upload tracking properties
      // The default values should be applied automatically
      final existingTrack = TrackData();
      
      await isar.writeTxn(() async {
        await isar.trackDatas.put(existingTrack);
      });

      final retrievedTrack = await isar.trackDatas.get(existingTrack.id);
      
      expect(retrievedTrack!.uploaded, isFalse);
      expect(retrievedTrack.uploadAttempts, equals(0));
      expect(retrievedTrack.lastUploadAttempt, isNull);
    });

    test('upload tracking properties work with existing functionality', () async {
      // Add some geolocation data
      final geolocation = GeolocationData()
        ..latitude = 52.5200
        ..longitude = 13.4050
        ..timestamp = DateTime.now().toUtc()
        ..speed = 0.0;

      await isar.writeTxn(() async {
        trackData.geolocations.add(geolocation);
        trackData.uploaded = true;
        trackData.uploadAttempts = 2;
        await isar.geolocationDatas.put(geolocation);
        await isar.trackDatas.put(trackData);
      });

      // Verify that existing functionality still works
      expect(trackData.encodedPolyline.isNotEmpty, isTrue);
      expect(trackData.distance, greaterThanOrEqualTo(0));
      expect(trackData.duration.inMilliseconds, greaterThanOrEqualTo(0));
      
      // Verify that upload tracking properties are preserved
      expect(trackData.uploaded, isTrue);
      expect(trackData.uploadAttempts, equals(2));
    });
  });
}