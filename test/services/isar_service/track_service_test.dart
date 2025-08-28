import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
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
    final mockIsarProvider = MockIsarProvider();
    when(() => mockIsarProvider.getDatabase()).thenAnswer((_) async => isar);
    trackService = TrackService(isarProvider: mockIsarProvider);

    await clearIsarDatabase(isar);

    trackData = createMockTrackData();
    await isar.writeTxn(() async {
      await isar.trackDatas.put(trackData);
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
        expect(trackData.uploaded, isFalse);

        // Mark track as uploaded
        await trackService.markTrackAsUploaded(trackData.id);

        // Verify track is now marked as uploaded in database
        final updatedTrack = await isar.trackDatas.get(trackData.id);
        expect(updatedTrack, isNotNull);
        expect(updatedTrack!.uploaded, isTrue);
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
        expect(updatedTrack!.uploaded, isTrue);
        expect(updatedTrack.uploadAttempts, equals(5));
        expect(updatedTrack.lastUploadAttempt, isNotNull);
      });

      test('can mark multiple tracks as uploaded', () async {
        // Create additional tracks
        final trackData2 = TrackData();
        final trackData3 = TrackData();

        await isar.writeTxn(() async {
          await isar.trackDatas.putAll([trackData2, trackData3]);
        });

        // Verify all tracks start as not uploaded
        expect(trackData.uploaded, isFalse);
        expect(trackData2.uploaded, isFalse);
        expect(trackData3.uploaded, isFalse);

        // Mark all tracks as uploaded
        await trackService.markTrackAsUploaded(trackData.id);
        await trackService.markTrackAsUploaded(trackData2.id);
        await trackService.markTrackAsUploaded(trackData3.id);

        // Verify all tracks are now marked as uploaded
        final updatedTrack1 = await isar.trackDatas.get(trackData.id);
        final updatedTrack2 = await isar.trackDatas.get(trackData2.id);
        final updatedTrack3 = await isar.trackDatas.get(trackData3.id);

        expect(updatedTrack1!.uploaded, isTrue);
        expect(updatedTrack2!.uploaded, isTrue);
        expect(updatedTrack3!.uploaded, isTrue);
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
        final uploadedTrack = TrackData()..uploaded = true;
        final unuploadedTrack1 = TrackData()..uploaded = false;
        final unuploadedTrack2 = TrackData()..uploaded = false;
        final unuploadedTrack3 = TrackData()..uploaded = false;

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
        expect(tracks.every((track) => !track.uploaded), isTrue);
        // Should return newest tracks first (highest IDs)
        expect(tracks[0].id, greaterThan(tracks[1].id));
      });

      test('retrieves unuploaded tracks with pagination and skips last track',
          () async {
        // Create tracks with different upload statuses
        final uploadedTrack = TrackData()..uploaded = true;
        final unuploadedTrack1 = TrackData()..uploaded = false;
        final unuploadedTrack2 = TrackData()..uploaded = false;
        final unuploadedTrack3 = TrackData()..uploaded = false;

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
        expect(tracks.every((track) => !track.uploaded), isTrue);
        // Should skip the newest unuploaded track
        expect(tracks[0].id, lessThan(unuploadedTrack3.id));
      });

      test('handles empty result when no unuploaded tracks exist', () async {
        // Clear database first and create only uploaded tracks
        await trackService.deleteAllTracks();
        
        final uploadedTrack1 = TrackData()..uploaded = true;
        final uploadedTrack2 = TrackData()..uploaded = true;

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
            List.generate(5, (index) => TrackData()..uploaded = false);

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
        final unuploadedTrack1 = TrackData()..uploaded = false;
        final unuploadedTrack2 = TrackData()..uploaded = false;
        final unuploadedTrack3 = TrackData()..uploaded = false;

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
    });
});
}