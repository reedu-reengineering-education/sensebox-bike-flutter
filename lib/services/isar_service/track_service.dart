// File: lib/services/isar_service/track_service.dart
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/track_summary_stats.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:isar_community/isar.dart';

class TrackService {
  final IsarProvider isarProvider;

  TrackService({required this.isarProvider});

  Future<Id> saveTrack(TrackData track) async {
    return isarProvider.runWriteTxn((isar) async {
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
    await isarProvider.runWriteTxn((isar) async {
      await isar.trackDatas.delete(id);
    });
  }

  Future<void> deleteAllTracks() async {
    await isarProvider.runWriteTxn((isar) async {
      await isar.trackDatas.clear();
    });
  }

  /// Marks a track as uploaded
  Future<void> markTrackAsUploaded(int trackId) async {
    await isarProvider.runWriteTxn((isar) async {
      final track = await isar.trackDatas.get(trackId);
      if (track != null) {
        track.uploaded = 1;
        await isar.trackDatas.put(track);
      }
    });
  }

  /// Updates a track with new data
  Future<void> updateTrack(TrackData track) async {
    await isarProvider.runWriteTxn((isar) async {
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

  /// Computes [track]'s cached* aggregate fields from its GeolocationData and
  /// persists them. Call once a track is done recording (its geolocations
  /// are all written) - see [RecordingBloc.stopRecording]. Idempotent: safe
  /// to call again (e.g. after retroactively editing points) to refresh.
  Future<void> cacheTrackAggregates(TrackData track) async {
    await track.geolocations.load();
    track.applyComputedAggregates();

    await isarProvider.runWriteTxn((isar) async {
      await isar.trackDatas.put(track);
    });
  }

  /// One-time migration for tracks recorded before the cached* fields
  /// existed. Self-terminating: each batch only picks up tracks that are
  /// still missing a cached point count, so once everything's migrated this
  /// becomes a single cheap empty query. Safe to call on every app/tracks
  /// screen start.
  Future<void> backfillMissingAggregates({int batchSize = 25}) async {
    while (true) {
      final isar = await isarProvider.getDatabase();
      final batch = await isar.trackDatas
          .filter()
          .cachedPointCountIsNull()
          .limit(batchSize)
          .findAll();

      if (batch.isEmpty) return;

      for (final track in batch) {
        await track.geolocations.load();
        track.applyComputedAggregates();
      }

      await isarProvider.runWriteTxn((isar) async {
        await isar.trackDatas.putAll(batch);
      });
    }
  }

  /// Summary stats for the tracks overview screen, computed entirely from
  /// TrackData's cached* columns via DB-side sum/count/min queries. Pass
  /// [recentSince] (start-of-week, etc.) to also get stats scoped to tracks
  /// that started on or after that moment. Never loads a GeolocationData row.
  Future<TrackSummaryStats> getSummaryStats({DateTime? recentSince}) async {
    final isar = await isarProvider.getDatabase();

    final totalTrackCount = await isar.trackDatas.count();
    final totalDistanceKm =
        await isar.trackDatas.where().cachedDistanceKmProperty().sum();
    final totalDurationMs =
        await isar.trackDatas.where().cachedDurationMsProperty().sum();
    final earliestStartTimestamp =
        await isar.trackDatas.where().cachedStartTimestampProperty().min();

    if (recentSince == null) {
      return TrackSummaryStats(
        totalTrackCount: totalTrackCount,
        totalDistanceKm: totalDistanceKm,
        totalDuration: Duration(milliseconds: totalDurationMs),
        earliestStartTimestamp: earliestStartTimestamp,
        recentTrackCount: 0,
        recentDistanceKm: 0,
        recentDuration: Duration.zero,
      );
    }

    final recentTrackCount = await isar.trackDatas
        .where()
        .cachedStartTimestampGreaterThan(recentSince, include: true)
        .count();
    final recentDistanceKm = await isar.trackDatas
        .where()
        .cachedStartTimestampGreaterThan(recentSince, include: true)
        .cachedDistanceKmProperty()
        .sum();
    final recentDurationMs = await isar.trackDatas
        .where()
        .cachedStartTimestampGreaterThan(recentSince, include: true)
        .cachedDurationMsProperty()
        .sum();

    return TrackSummaryStats(
      totalTrackCount: totalTrackCount,
      totalDistanceKm: totalDistanceKm,
      totalDuration: Duration(milliseconds: totalDurationMs),
      earliestStartTimestamp: earliestStartTimestamp,
      recentTrackCount: recentTrackCount,
      recentDistanceKm: recentDistanceKm,
      recentDuration: Duration(milliseconds: recentDurationMs),
    );
  }
}
