// File: lib/services/isar_service/geolocation_service.dart
import 'dart:async';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/geolocation_dto.dart';
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

  Future<void> deleteAllGeolocations() async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      await isar.geolocationDatas.clear();
    });
  }

  Future<void> saveGeolocationsBatch(List<GeolocationDto> geolocations) async {
    final isar = await isarProvider.getDatabase();

    await isar.writeTxn(() async {
      for (final dto in geolocations) {
        final geo = GeolocationData()
          ..latitude = dto.latitude
          ..longitude = dto.longitude
          ..speed = dto.speed
          ..timestamp = dto.timestamp;

        // Get the track and set the link
        final track = await isar.trackDatas.get(dto.trackId);
        if (track != null) {
          geo.track.value = track;
          await isar.geolocationDatas.put(geo);
          await geo.track.save();
        }
      }
    });
  }
}
