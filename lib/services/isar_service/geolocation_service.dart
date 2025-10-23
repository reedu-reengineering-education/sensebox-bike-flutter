// File: lib/services/isar_service/geolocation_service.dart
import 'dart:async';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:isar_community/isar.dart';

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
      Id geoDataId = await isar.geolocationDatas.put(geolocationData);
      await geolocationData.track.save();
      return geoDataId;
    });
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

  Future<List<GeolocationData>> getGeolocationDataWithPreloadedSensors(
      int trackId) async {
    final isar = await isarProvider.getDatabase();
    return await isar.txn(() async {
      final geolocations = await isar.geolocationDatas
          .where()
          .filter()
          .track((q) => q.idEqualTo(trackId))
          .findAll();

      // Pre-load sensor data for all geolocations
      for (final geo in geolocations) {
        await geo.sensorData.load();
      }

      return geolocations;
    });
  }

  Future<void> deleteAllGeolocations() async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      await isar.geolocationDatas.clear();
    });
  }
}
