// File: lib/services/isar_service/geolocation_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
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
          } catch (e) {
            // Note: We don't retry here to avoid nested transactions
            // The geolocation data is still saved, just without the track link
          }
        }
        
        return geoDataId;
      } catch (e) {
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
        } else {
          debugPrint(
              'Warning: Could not establish track link - geolocation or track not found');
        }
      });
      return true;
    } catch (e) {
      debugPrint('Error establishing track link: $e');
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

  Future<void> deleteAllGeolocations() async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      await isar.geolocationDatas.clear();
    });
  }
}
