// File: lib/services/isar_service/geolocation_service.dart
import 'dart:async';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:isar/isar.dart';

class GeolocationService {
  final IsarProvider isarProvider;

  GeolocationService({required this.isarProvider});

  Future<Stream<void>> getGeolocationStream() async {
    final isar = await isarProvider.getDatabase();
    return isar.geolocationDatas.watchLazy(fireImmediately: true);
  }

  Future<GeolocationData?> getLastGeolocationData() async {
    final isar = await isarProvider.getDatabase();
    return await isar.geolocationDatas
        .where()
        .sortByTimestampDesc()
        .findFirst();
  }

  Future<Id> saveGeolocationData(GeolocationData geolocationData) async {
    final isar = await isarProvider.getDatabase();
    return await isar.writeTxn(() async {
      try {
        // Save the geolocation data first
        Id geoDataId = await isar.geolocationDatas.put(geolocationData);
        
        // Only save the link if the track is properly set
        if (geolocationData.track.value != null) {
          try {
            await geolocationData.track.save();
            print(
                'Successfully saved geolocation data with track link: $geoDataId');
          } catch (e) {
            // If link saving fails, log the error but don't fail the entire operation
            // This can happen if the track object has been moved or there are link conflicts
            print(
                'Warning: Failed to save track link for geolocation $geoDataId: $e');
            // Note: We don't retry here to avoid nested transactions
            // The geolocation data is still saved, just without the track link
          }
        } else {
          print('Warning: No track set for geolocation data: $geoDataId');
        }
        
        return geoDataId;
      } catch (e) {
        print('Error saving geolocation data: $e');
        rethrow;
      }
    });
  }

  /// Establish track link for a geolocation data entry (can be called separately if needed)
  Future<bool> establishTrackLink(int geolocationId, int trackId) async {
    final isar = await isarProvider.getDatabase();
    try {
      await isar.writeTxn(() async {
        final geoData = await isar.geolocationDatas.get(geolocationId);
        final track = await isar.trackDatas.get(trackId);

        if (geoData != null && track != null) {
          geoData.track.value = track;
          await isar.geolocationDatas.put(geoData);
          await geoData.track.save();
          print(
              'Successfully established track link for geolocation: $geolocationId');
        } else {
          print(
              'Warning: Could not establish track link - geolocation or track not found');
        }
      });
      return true;
    } catch (e) {
      print('Error establishing track link: $e');
      return false;
    }
  }

  Future<List<GeolocationData>> getGeolocationData() async {
    final isar = await isarProvider.getDatabase();
    return await isar.geolocationDatas.where().findAll();
  }

  Future<List<GeolocationData>> getGeolocationDataByTrackId(int trackId) async {
    final isar = await isarProvider.getDatabase();
    return await isar.geolocationDatas.where().filter().track((q) {
      return q.idEqualTo(trackId);
    }).findAll();
  }

  /// Optimized method to get geolocation data in batches for large datasets
  Future<List<GeolocationData>> getGeolocationDataByTrackIdPaginated(
    int trackId, {
    int offset = 0,
    int limit = 100,
  }) async {
    final isar = await isarProvider.getDatabase();
    return await isar.geolocationDatas
        .where()
        .filter()
        .track((q) => q.idEqualTo(trackId))
        .sortByTimestamp()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  /// Get only unuploaded geolocation data (excluding the last item which may be incomplete)
  Future<List<GeolocationData>> getUnuploadedGeolocationDataByTrackId(
    int trackId, {
    int batchSize = 50,
  }) async {
    final isar = await isarProvider.getDatabase();

    // Get total count for this track
    final totalCount = await isar.geolocationDatas
        .where()
        .filter()
        .track((q) => q.idEqualTo(trackId))
        .count();

    // If we have less than 2 items, return empty (need at least 2 to exclude the last)
    if (totalCount < 2) {
      return [];
    }

    // Get all but the last item (which may be incomplete)
    final dataToUpload = await isar.geolocationDatas
        .where()
        .filter()
        .track((q) => q.idEqualTo(trackId))
        .sortByTimestamp()
        .limit(totalCount - 1)
        .findAll();

    return dataToUpload;
  }

  /// Get count of geolocation data for a track
  Future<int> getGeolocationCountByTrackId(int trackId) async {
    final isar = await isarProvider.getDatabase();
    return await isar.geolocationDatas
        .where()
        .filter()
        .track((q) => q.idEqualTo(trackId))
        .count();
  }

  Future<void> deleteAllGeolocations() async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      await isar.geolocationDatas.clear();
    });
  }
}
