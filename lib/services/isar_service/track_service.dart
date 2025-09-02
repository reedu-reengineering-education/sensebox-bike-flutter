// File: lib/services/isar_service/track_service.dart
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:isar/isar.dart';

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
    
    if (skipLastTrack) {
      // Get the last track to check if it's unuploaded
      final lastTrack = await getLastTrack();
      
      if (lastTrack != null && lastTrack.uploaded != 1) {
        // If the last track is unuploaded, we need to skip it
        // Get all tracks, filter unuploaded ones, then apply pagination
        final allTracks = await isar.trackDatas.where().findAll();
        final unuploadedTracks = allTracks
            .where((track) => track.uploaded != 1 && track.isDirectUpload != 1)
            .toList();
        
        // Sort by ID in descending order (newest first)
        unuploadedTracks.sort((a, b) => b.id.compareTo(a.id));
        
        // Apply pagination and skip the last track
        final startIndex = offset;
        final paginatedTracks = unuploadedTracks.skip(startIndex).take(limit + 1).toList();
        
        // Skip the last track (which is the first in the list due to descending sort)
        return paginatedTracks.skip(1).toList();
      } else {
        // Last track is uploaded or doesn't exist, no need to skip
        final allTracks = await isar.trackDatas.where().findAll();
        final unuploadedTracks = allTracks
            .where((track) => track.uploaded != 1 && track.isDirectUpload != 1)
            .toList();
        
        // Sort by ID in descending order (newest first)
        unuploadedTracks.sort((a, b) => b.id.compareTo(a.id));
        
        // Apply pagination
        final startIndex = offset;
        return unuploadedTracks.skip(startIndex).take(limit).toList();
      }
    } else {
      // No need to skip last track
      final allTracks = await isar.trackDatas.where().findAll();
      final unuploadedTracks = allTracks
          .where((track) => track.uploaded != 1 && track.isDirectUpload != 1)
          .toList();
      
      // Sort by ID in descending order (newest first)
      unuploadedTracks.sort((a, b) => b.id.compareTo(a.id));
      
      // Apply pagination
      final startIndex = offset;
      return unuploadedTracks.skip(startIndex).take(limit).toList();
    }
  }

  Future<TrackData?> getLastTrack() async {
    final isar = await isarProvider.getDatabase();
    return await isar.trackDatas
        .where(sort: Sort.desc)
        .anyId()
        .findFirst();
  }
}
