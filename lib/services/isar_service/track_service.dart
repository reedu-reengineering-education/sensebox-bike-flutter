// File: lib/services/isar_service/track_service.dart
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:isar_community/isar.dart';

class TrackService {
  final IsarProvider isarProvider;

  TrackService({required this.isarProvider});

  Future<Id> saveTrack(TrackData track) async {
    final isar = await isarProvider.getDatabase();
    return await isar.writeTxn(() async {
      return await isar.trackDatas.put(track);
    });
  }

  Future<TrackData?> getTrackById(int id) async {
    final isar = await isarProvider.getDatabase();
    return await isar.trackDatas.get(id);
  }

  Future<List<TrackData>> getAllTracks() async {
    final isar = await isarProvider.getDatabase();
    final tracks = await isar.trackDatas.where().findAll();
    return tracks.toList();
  }

  Future<void> deleteTrack(int id) async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      await isar.trackDatas.delete(id);
    });
  }

  Future<void> deleteAllTracks() async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      await isar.trackDatas.clear();
    });
  }

  /// Marks a track as uploaded
  Future<void> markTrackAsUploaded(int trackId) async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      final track = await isar.trackDatas.get(trackId);
      if (track != null) {
        track.uploaded = 1;
        await isar.trackDatas.put(track);
      }
    });
  }

  /// Updates a track with new data
  Future<void> updateTrack(TrackData track) async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      await isar.trackDatas.put(track);
    });
  }

  Future<List<TrackData>> getTracksPaginated(
      {required int offset,
      required int limit,
      bool skipLastTrack = false}) async {
    final isar = await isarProvider.getDatabase();
    
    if (skipLastTrack) {
      // Get one extra track to account for skipping the last one
      final tracks = await isar.trackDatas
          .where(sort: Sort.desc)
          .anyId()
          .offset(offset)
          .limit(limit + 1)
          .findAll();

      // Skip the last track (which is the first in the list due to Sort.desc)
      return tracks.skip(1).toList();
    } else {
      return await isar.trackDatas
          .where(sort: Sort.desc)
          .anyId()
          .offset(offset)
          .limit(limit)
          .findAll();
    }
  }

  Future<List<TrackData>> getUnuploadedTracksPaginated(
      {required int offset,
      required int limit,
      bool skipLastTrack = false}) async {
    final isar = await isarProvider.getDatabase();

    var effectiveOffset = offset;
    if (skipLastTrack) {
      // Skip the newest entry only when it would actually be part of this
      // filtered unuploaded query; otherwise don't shift pagination.
      final lastTrack = await getLastTrack();
      if (lastTrack != null &&
          lastTrack.uploaded != 1 &&
          _shouldIncludeInUnuploadedTracks(lastTrack)) {
        effectiveOffset += 1;
      }
    }

    return await isar.trackDatas
        .where(sort: Sort.desc)
        .anyId()
        .filter()
        .not()
        .uploadedEqualTo(1)
        .and()
        .group((q) => q
            .not()
            .isDirectUploadEqualTo(1)
            .or()
            .uploadAttemptsGreaterThan(0))
        .offset(effectiveOffset)
        .limit(limit)
        .findAll();
  }

  Future<TrackData?> getLastTrack() async {
    final isar = await isarProvider.getDatabase();
    return await isar.trackDatas
        .where(sort: Sort.desc)
        .anyId()
        .findFirst();
  }

  /// Determines if a track should be included in unuploaded tracks filtering.
  /// Returns true for batch upload tracks or direct upload tracks with upload attempts.
  bool _shouldIncludeInUnuploadedTracks(TrackData track) {
    return track.isDirectUpload != 1 || track.uploadAttemptsCount > 0;
  }
}
