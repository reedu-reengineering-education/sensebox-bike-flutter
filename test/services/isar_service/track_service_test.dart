import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:flutter/services.dart';
import '../../test_helpers.dart';
import '../../mocks.dart';

void main() {
  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  late Isar isar;
  late TrackService trackService;
  late TrackData trackData;
  late Directory tempDirectory;

  setUp(() async {
    initializeTestDependencies();

    tempDirectory = Directory.systemTemp.createTempSync();
    mockPathProvider(tempDirectory.path);

    isar = await initializeInMemoryIsar();
    trackService = TrackService(isarProvider: TestIsarProvider(isar));

    await clearIsarDatabase(isar);

    trackData = createMockTrackData();
    trackData.isDirectUpload = 0; // Set to false for batch upload testing
    await isar.writeTxn(() async {
      final id = await isar.trackDatas.put(trackData);
      trackData.id = id;
    });
  });

  tearDown(() async {
    await isar.close();
    channel.setMockMethodCallHandler(null);
  });

group('TrackService', () {
    group('deleteAllTracks', () {
      test('successfully deletes all tracks from the database', () async {
        final tracksBefore = await isar.trackDatas.where().findAll();
        expect(tracksBefore.length, equals(1));

        await trackService.deleteAllTracks();

        final tracksAfter = await isar.trackDatas.where().findAll();
        expect(tracksAfter.isEmpty, isTrue);
      });

      test('handles empty database gracefully', () async {
        await trackService.deleteAllTracks();

        await trackService.deleteAllTracks();

        final tracksAfter = await isar.trackDatas.where().findAll();
        expect(tracksAfter.isEmpty, isTrue);
      });

      test('deletes multiple tracks from the database', () async {
        final trackData2 = TrackData();
        await isar.writeTxn(() async {
          await isar.trackDatas.put(trackData2);
        });

        final tracksBefore = await isar.trackDatas.where().findAll();
        expect(tracksBefore.length, equals(2));

        await trackService.deleteAllTracks();

        final tracksAfter = await isar.trackDatas.where().findAll();
        expect(tracksAfter.isEmpty, isTrue);
      });
    });

    group('saveTrack', () {
      test('successfully saves a track to the database', () async {
        final newTrack = TrackData();
        final trackId = await trackService.saveTrack(newTrack);

        final savedTrack = await isar.trackDatas.get(trackId);
        expect(savedTrack, isNotNull);
      });
    });

    group('getTrackById', () {
      test('retrieves a track by its ID', () async {
        final retrievedTrack = await trackService.getTrackById(trackData.id);
        expect(retrievedTrack, isNotNull);
        expect(retrievedTrack?.id, equals(trackData.id));
      });

      test('returns null for a non-existent track ID', () async {
        final retrievedTrack = await trackService.getTrackById(-1);
        expect(retrievedTrack, isNull);
      });
    });

    group('getAllTracks', () {
      test('retrieves all tracks from the database', () async {
        final trackData2 = TrackData();
        await isar.writeTxn(() async {
          await isar.trackDatas.put(trackData2);
        });

        final allTracks = await trackService.getAllTracks();
        expect(allTracks.length, equals(2));
      });

      test('returns empty list when no tracks exist', () async {
        await trackService.deleteAllTracks();

        final allTracks = await trackService.getAllTracks();
        expect(allTracks.isEmpty, isTrue);
      });
    });

    group('markTrackAsUploaded', () {
      test('successfully marks a track as uploaded', () async {
        // Verify track starts as not uploaded
        expect(trackData.isUploaded, isFalse);

        // Mark track as uploaded
        await trackService.markTrackAsUploaded(trackData.id);

        // Verify track is now marked as uploaded in database
        final updatedTrack = await isar.trackDatas.get(trackData.id);
        expect(updatedTrack, isNotNull);
        expect(updatedTrack!.isUploaded, isTrue);
      });

      test('handles non-existent track ID gracefully', () async {
        // Should not throw an exception for non-existent track
        await expectLater(
          trackService.markTrackAsUploaded(-1),
          completes,
        );
      });

      test('preserves other track properties when marking as uploaded',
          () async {
        // Set some other properties to verify they're preserved
        await isar.writeTxn(() async {
          trackData.uploadAttempts = 5;
          trackData.lastUploadAttempt = DateTime.now();
          await isar.trackDatas.put(trackData);
        });

        // Mark track as uploaded
        await trackService.markTrackAsUploaded(trackData.id);

        // Verify track is uploaded and other properties are preserved
        final updatedTrack = await isar.trackDatas.get(trackData.id);
        expect(updatedTrack, isNotNull);
        expect(updatedTrack!.isUploaded, isTrue);
        expect(updatedTrack.uploadAttempts, equals(5));
        expect(updatedTrack.lastUploadAttempt, isNotNull);
      });

      test('can mark multiple tracks as uploaded', () async {
        // Create additional tracks
        final trackData2 = TrackData()..id = 2;
        final trackData3 = TrackData()..id = 3;

        await isar.writeTxn(() async {
          await isar.trackDatas.putAll([trackData2, trackData3]);
        });

        // Verify all tracks start as not uploaded
        expect(trackData.isUploaded, isFalse);
        expect(trackData2.isUploaded, isFalse);
        expect(trackData3.isUploaded, isFalse);

        // Mark all tracks as uploaded
        await trackService.markTrackAsUploaded(trackData.id);
        await trackService.markTrackAsUploaded(trackData2.id);
        await trackService.markTrackAsUploaded(trackData3.id);

        // Verify all tracks are now marked as uploaded
        final updatedTrack1 = await isar.trackDatas.get(trackData.id);
        final updatedTrack2 = await isar.trackDatas.get(trackData2.id);
        final updatedTrack3 = await isar.trackDatas.get(trackData3.id);

        expect(updatedTrack1!.isUploaded, isTrue);
        expect(updatedTrack2!.isUploaded, isTrue);
        expect(updatedTrack3!.isUploaded, isTrue);
      });
    });

    group('getUnuploadedTracksPaginated - isDirectUpload filtering', () {
      test('excludes direct upload tracks from not uploaded filter', () async {
        // Clear database to ensure clean state
        await clearIsarDatabase(isar);
        
        // Create tracks with different combinations
        final track1 = TrackData()
          ..id = 101
          ..uploaded = 0
          ..isDirectUpload = 0; // Batch upload, not uploaded
        
        final track2 = TrackData()
          ..id = 102
          ..uploaded = 0
          ..isDirectUpload = 1; // Direct upload, not uploaded - should be excluded
        
        final track3 = TrackData()
          ..id = 103
          ..uploaded = 0
          ..isDirectUpload = 0; // Batch upload, not uploaded

        // Save tracks
        await isar.writeTxn(() async {
          await isar.trackDatas.putAll([track1, track2, track3]);
        });

        // Get unuploaded tracks
        final unuploadedTracks = await trackService.getUnuploadedTracksPaginated(
          offset: 0,
          limit: 10,
        );

        // Should return 2 tracks: track1 and track3
        // track2 is excluded because it's a direct upload track
        expect(unuploadedTracks.length, equals(2));
        
        // Verify the returned tracks are the expected ones
        final trackIds = unuploadedTracks.map((t) => t.id).toSet();
        expect(trackIds, contains(track1.id));
        expect(trackIds, contains(track3.id));
        expect(trackIds, isNot(contains(track2.id)));
      });

      test('includes batch upload tracks that are not uploaded', () async {
        // Clear database to ensure clean state
        await clearIsarDatabase(isar);
        
        // Create a batch upload track that is not uploaded
        final batchUploadTrack = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0;

        await isar.writeTxn(() async {
          await isar.trackDatas.put(batchUploadTrack);
        });

        final unuploadedTracks = await trackService.getUnuploadedTracksPaginated(
          offset: 0,
          limit: 10,
        );

        // Should contain the unuploaded batch upload track
        expect(unuploadedTracks.length, equals(1));
        expect(unuploadedTracks.first.id, equals(batchUploadTrack.id));
      });

      test('excludes direct upload tracks regardless of upload status', () async {
        // Clear database to ensure clean state
        await clearIsarDatabase(isar);
        
        // Create direct upload tracks with different upload statuses
        final directUploadTrack1 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 1; // Not uploaded, direct upload - should be excluded
        
        final directUploadTrack2 = TrackData()
          ..uploaded = 1
          ..isDirectUpload = 1; // Uploaded, direct upload - should be excluded

        await isar.writeTxn(() async {
          await isar.trackDatas.putAll([directUploadTrack1, directUploadTrack2]);
        });

        final unuploadedTracks = await trackService.getUnuploadedTracksPaginated(
          offset: 0,
          limit: 10,
        );

        // Should not contain any direct upload tracks
        expect(unuploadedTracks.length, equals(0));
      });

      test('excludes uploaded tracks regardless of upload mode', () async {
        // Clear database to ensure clean state
        await clearIsarDatabase(isar);
        
        // Create tracks with different combinations
        final track1 = TrackData()
          ..uploaded = 1
          ..isDirectUpload = 1; // Uploaded, direct upload - should be excluded
        
        final track2 = TrackData()
          ..uploaded = 1
          ..isDirectUpload = 0; // Uploaded, batch upload - should be excluded
        
        final track3 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0; // Not uploaded, batch upload - should be included

        await isar.writeTxn(() async {
          await isar.trackDatas.putAll([track1, track2, track3]);
        });

        final unuploadedTracks = await trackService.getUnuploadedTracksPaginated(
          offset: 0,
          limit: 10,
        );

        // Should only return track3 (not uploaded, batch upload)
        expect(unuploadedTracks.length, equals(1));
        expect(unuploadedTracks.first.id, equals(track3.id));
      });
    });

    group('deleteTrack', () {
      test('successfully deletes a track by its ID', () async {
        await trackService.deleteTrack(trackData.id);

        final deletedTrack = await isar.trackDatas.get(trackData.id);
        expect(deletedTrack, isNull);
      });

      test('handles deletion of a non-existent track gracefully', () async {
        await trackService.deleteTrack(-1);

        final tracks = await isar.trackDatas.where().findAll();
        expect(tracks.length, equals(1)); // Original track remains
      });
    });

    group('getTracksPaginated', () {
      test('retrieves paginated tracks without skipping last track', () async {
        // Create multiple tracks
        final track1 = TrackData();
        final track2 = TrackData();
        final track3 = TrackData();

        await isar.writeTxn(() async {
          await isar.trackDatas.put(track1);
          await isar.trackDatas.put(track2);
          await isar.trackDatas.put(track3);
        });

        final tracks = await trackService.getTracksPaginated(
            offset: 0, limit: 2, skipLastTrack: false);

        expect(tracks.length, equals(2));
        // Should return newest tracks first (highest IDs)
        expect(tracks[0].id, greaterThan(tracks[1].id));
      });

      test(
          'retrieves paginated tracks and skips the last track when skipLastTrack is true',
          () async {
        // Create multiple tracks
        final track1 = TrackData();
        final track2 = TrackData();
        final track3 = TrackData();

        await isar.writeTxn(() async {
          await isar.trackDatas.put(track1);
          await isar.trackDatas.put(track2);
          await isar.trackDatas.put(track3);
        });

        final tracks = await trackService.getTracksPaginated(
            offset: 0, limit: 2, skipLastTrack: true);

        expect(tracks.length, equals(2));
        // Should skip the newest track (highest ID) and return the next two
        expect(tracks[0].id,
            lessThan(track3.id)); // Should not include the newest track
      });

      test('handles empty result when skipLastTrack is true', () async {
        final tracks = await trackService.getTracksPaginated(
            offset: 0, limit: 10, skipLastTrack: true);

        expect(tracks.isEmpty, isTrue);
      });
    });

    group('getUnuploadedTracksPaginated', () {
      test('retrieves only unuploaded tracks with pagination', () async {
        // Create tracks with different upload statuses
        final uploadedTrack = TrackData()..uploaded = 1;
        final unuploadedTrack1 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0; // Explicitly set to false for batch upload
        final unuploadedTrack2 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0; // Explicitly set to false for batch upload
        final unuploadedTrack3 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0; // Explicitly set to false for batch upload

        await isar.writeTxn(() async {
          await isar.trackDatas.putAll([
            uploadedTrack,
            unuploadedTrack1,
            unuploadedTrack2,
            unuploadedTrack3
          ]);
        });

        final tracks = await trackService.getUnuploadedTracksPaginated(
            offset: 0, limit: 2, skipLastTrack: false);

        expect(tracks.length, equals(2));
        // Should only return unuploaded tracks
        expect(tracks.every((track) => !track.isUploaded), isTrue);
        // Should return newest tracks first (highest IDs)
        expect(tracks[0].id, greaterThan(tracks[1].id));
      });

      test('retrieves unuploaded tracks with pagination and skips last track',
          () async {
        // Create tracks with different upload statuses
        final uploadedTrack = TrackData()..uploaded = 1;
        final unuploadedTrack1 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0; // Explicitly set to false for batch upload
        final unuploadedTrack2 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0; // Explicitly set to false for batch upload
        final unuploadedTrack3 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0; // Explicitly set to false for batch upload

        await isar.writeTxn(() async {
          await isar.trackDatas.putAll([
            uploadedTrack,
            unuploadedTrack1,
            unuploadedTrack2,
            unuploadedTrack3
          ]);
        });

        final tracks = await trackService.getUnuploadedTracksPaginated(
            offset: 0, limit: 2, skipLastTrack: true);

        expect(tracks.length, equals(2));
        // Should only return unuploaded tracks
        expect(tracks.every((track) => !track.isUploaded), isTrue);
        // Should skip the newest unuploaded track
        expect(tracks[0].id, lessThan(unuploadedTrack3.id));
      });

      test('handles empty result when no unuploaded tracks exist', () async {
        // Clear database first and create only uploaded tracks
        await trackService.deleteAllTracks();
        
        final uploadedTrack1 = TrackData()..uploaded = 1;
        final uploadedTrack2 = TrackData()..uploaded = 1;

        await isar.writeTxn(() async {
          await isar.trackDatas.putAll([uploadedTrack1, uploadedTrack2]);
        });

        final tracks = await trackService.getUnuploadedTracksPaginated(
            offset: 0, limit: 10, skipLastTrack: false);

        expect(tracks.isEmpty, isTrue);
      });

      test('handles pagination correctly for unuploaded tracks', () async {
        // Clear database first to have exact control over the number of tracks
        await trackService.deleteAllTracks();
        
        // Create exactly 5 unuploaded tracks
        final unuploadedTracks =
            List.generate(5, (index) => TrackData()
              ..uploaded = 0
              ..isDirectUpload = 0); // Explicitly set to false for batch upload

        await isar.writeTxn(() async {
          await isar.trackDatas.putAll(unuploadedTracks);
        });

        // First page
        final firstPage = await trackService.getUnuploadedTracksPaginated(
            offset: 0, limit: 2, skipLastTrack: false);
        expect(firstPage.length, equals(2));

        // Second page
        final secondPage = await trackService.getUnuploadedTracksPaginated(
            offset: 2, limit: 2, skipLastTrack: false);
        expect(secondPage.length, equals(2));

        // Third page (should have only 1 track left)
        final thirdPage = await trackService.getUnuploadedTracksPaginated(
            offset: 4, limit: 2, skipLastTrack: false);
        expect(thirdPage.length, equals(1));

        // Fourth page (should be empty)
        final fourthPage = await trackService.getUnuploadedTracksPaginated(
            offset: 6, limit: 2, skipLastTrack: false);
        expect(fourthPage.isEmpty, isTrue);
      });

      test('maintains correct sorting order for unuploaded tracks', () async {
        // Create unuploaded tracks with specific IDs
        final unuploadedTrack1 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0; // Explicitly set to false for batch upload
        final unuploadedTrack2 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0; // Explicitly set to false for batch upload
        final unuploadedTrack3 = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0; // Explicitly set to false for batch upload

        await isar.writeTxn(() async {
          await isar.trackDatas.put(unuploadedTrack1);
          await isar.trackDatas.put(unuploadedTrack2);
          await isar.trackDatas.put(unuploadedTrack3);
        });

        final tracks = await trackService.getUnuploadedTracksPaginated(
            offset: 0, limit: 3, skipLastTrack: false);

        expect(tracks.length, equals(3));
        // Should be sorted by ID in descending order (newest first)
        expect(tracks[0].id, equals(unuploadedTrack3.id));
        expect(tracks[1].id, equals(unuploadedTrack2.id));
        expect(tracks[2].id, equals(unuploadedTrack1.id));
      });

      test(
          'skipLastTrack does not skip extra item when newest track is filtered out',
          () async {
        await trackService.deleteAllTracks();

        final newestFilteredOut = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 1
          ..uploadAttempts = 0;

        final expectedFirst = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0;

        final expectedSecond = TrackData()
          ..uploaded = 0
          ..isDirectUpload = 0;

        await isar.writeTxn(() async {
          await isar.trackDatas.put(newestFilteredOut);
          await isar.trackDatas.put(expectedFirst);
          await isar.trackDatas.put(expectedSecond);
        });

        final tracks = await trackService.getUnuploadedTracksPaginated(
          offset: 0,
          limit: 10,
          skipLastTrack: true,
        );

        final ids = tracks.map((t) => t.id).toSet();
        expect(ids, isNot(contains(newestFilteredOut.id)));
        expect(tracks.length, equals(1));
      });
    });

    group('cacheTrackAggregates', () {
      Future<TrackData> putTrackWithGeolocations(
          List<GeolocationData> geolocations) async {
        final track = TrackData();
        await isar.writeTxn(() async {
          await isar.trackDatas.put(track);
          for (final geo in geolocations) {
            geo.track.value = track;
            await isar.geolocationDatas.put(geo);
            await geo.track.save();
          }
        });
        return track;
      }

      test('computes and persists distance/duration/point count/polyline',
          () async {
        final start = DateTime(2024, 1, 1, 10, 0, 0);
        final track = await putTrackWithGeolocations([
          GeolocationData()
            ..latitude = 52.5200
            ..longitude = 13.4050
            ..timestamp = start
            ..speed = 0,
          GeolocationData()
            ..latitude = 52.5300
            ..longitude = 13.4150
            ..timestamp = start.add(const Duration(minutes: 10))
            ..speed = 0,
        ]);

        await trackService.cacheTrackAggregates(track);

        final reloaded = await isar.trackDatas.get(track.id);
        expect(reloaded, isNotNull);
        expect(reloaded!.cachedPointCount, equals(2));
        expect(reloaded.cachedStartTimestamp, equals(start));
        expect(reloaded.cachedEndTimestamp,
            equals(start.add(const Duration(minutes: 10))));
        expect(reloaded.cachedDurationMs,
            equals(const Duration(minutes: 10).inMilliseconds));
        expect(reloaded.cachedDistanceKm, greaterThan(0));
        expect(reloaded.cachedPolyline, isNotEmpty);

        // The plain getters should now read straight from the cache without
        // touching the geolocations link.
        expect(reloaded.duration, equals(const Duration(minutes: 10)));
        expect(reloaded.distance, equals(reloaded.cachedDistanceKm));
      });

      test('caches zeroed-out fields for a track with no geolocations',
          () async {
        final track = await putTrackWithGeolocations([]);

        await trackService.cacheTrackAggregates(track);

        final reloaded = await isar.trackDatas.get(track.id);
        expect(reloaded!.cachedPointCount, equals(0));
        expect(reloaded.cachedStartTimestamp, isNull);
        expect(reloaded.cachedEndTimestamp, isNull);
        expect(reloaded.cachedDurationMs, equals(0));
        expect(reloaded.cachedDistanceKm, equals(0));
        expect(reloaded.hasGeolocationData, isFalse);
      });
    });

    group('backfillMissingAggregates', () {
      test('populates cached fields for legacy tracks missing them',
          () async {
        await clearIsarDatabase(isar);

        final start = DateTime(2024, 1, 1, 10, 0, 0);
        final legacyTrack = TrackData();
        await isar.writeTxn(() async {
          await isar.trackDatas.put(legacyTrack);
          final geo = GeolocationData()
            ..latitude = 52.5200
            ..longitude = 13.4050
            ..timestamp = start
            ..speed = 0
            ..track.value = legacyTrack;
          await isar.geolocationDatas.put(geo);
          await geo.track.save();
        });

        expect(legacyTrack.cachedPointCount, isNull);

        await trackService.backfillMissingAggregates();

        final reloaded = await isar.trackDatas.get(legacyTrack.id);
        expect(reloaded!.cachedPointCount, equals(1));
        expect(reloaded.cachedStartTimestamp, equals(start));
      });

      test('is a no-op once every track is already cached', () async {
        await clearIsarDatabase(isar);

        final track = TrackData()
          ..cachedPointCount = 0
          ..cachedDistanceKm = 0
          ..cachedDurationMs = 0;
        await isar.writeTxn(() async {
          await isar.trackDatas.put(track);
        });

        // Should return promptly without throwing, touching nothing.
        await expectLater(
          trackService.backfillMissingAggregates(),
          completes,
        );
      });
    });

    group('getSummaryStats', () {
      test('sums cached fields across all tracks without recentSince',
          () async {
        await clearIsarDatabase(isar);

        final trackA = TrackData()
          ..cachedDistanceKm = 5.0
          ..cachedDurationMs = const Duration(minutes: 10).inMilliseconds
          ..cachedStartTimestamp = DateTime(2024, 1, 1);
        final trackB = TrackData()
          ..cachedDistanceKm = 7.5
          ..cachedDurationMs = const Duration(minutes: 20).inMilliseconds
          ..cachedStartTimestamp = DateTime(2024, 2, 1);

        await isar.writeTxn(() async {
          await isar.trackDatas.putAll([trackA, trackB]);
        });

        final stats = await trackService.getSummaryStats();

        expect(stats.totalTrackCount, equals(2));
        expect(stats.totalDistanceKm, equals(12.5));
        expect(stats.totalDuration, equals(const Duration(minutes: 30)));
        expect(stats.earliestStartTimestamp, equals(DateTime(2024, 1, 1)));
        expect(stats.recentTrackCount, equals(0));
      });

      test('scopes recent* fields to tracks starting on/after recentSince',
          () async {
        await clearIsarDatabase(isar);

        final oldTrack = TrackData()
          ..cachedDistanceKm = 3.0
          ..cachedDurationMs = const Duration(minutes: 5).inMilliseconds
          ..cachedStartTimestamp = DateTime(2024, 1, 1);
        final recentTrack = TrackData()
          ..cachedDistanceKm = 4.0
          ..cachedDurationMs = const Duration(minutes: 8).inMilliseconds
          ..cachedStartTimestamp = DateTime(2024, 6, 15);

        await isar.writeTxn(() async {
          await isar.trackDatas.putAll([oldTrack, recentTrack]);
        });

        final stats = await trackService.getSummaryStats(
          recentSince: DateTime(2024, 6, 1),
        );

        expect(stats.totalTrackCount, equals(2));
        expect(stats.totalDistanceKm, equals(7.0));
        expect(stats.recentTrackCount, equals(1));
        expect(stats.recentDistanceKm, equals(4.0));
        expect(stats.recentDuration, equals(const Duration(minutes: 8)));
      });

      test('returns zeroed stats for an empty database', () async {
        await clearIsarDatabase(isar);

        final stats = await trackService.getSummaryStats(
          recentSince: DateTime(2024, 1, 1),
        );

        expect(stats.totalTrackCount, equals(0));
        expect(stats.totalDistanceKm, equals(0));
        expect(stats.totalDuration, equals(Duration.zero));
        expect(stats.earliestStartTimestamp, isNull);
        expect(stats.recentTrackCount, equals(0));
      });
    });
});
}