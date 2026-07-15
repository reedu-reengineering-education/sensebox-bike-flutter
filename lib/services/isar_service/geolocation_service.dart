// File: lib/services/isar_service/geolocation_service.dart
import 'dart:async';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
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

  Future<Id> saveGeolocationData(GeolocationData geolocationData) {
    return saveGeolocationWithSensors(geolocationData, const []);
  }

  /// Persists a geolocation and optional sensor rows in a single write transaction.
  Future<Id> saveGeolocationWithSensors(
    GeolocationData geolocationData,
    List<SensorData> sensorData,
  ) {
    return isarProvider.runWriteTxn((isar) async {
      final geoDataId = await isar.geolocationDatas.put(geolocationData);
      await geolocationData.track.save();

      if (sensorData.isEmpty) {
        return geoDataId;
      }

      geolocationData.id = geoDataId;
      await putSensorRows(isar, sensorData, geolocation: geolocationData);
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

      for (final geo in geolocations) {
        await geo.sensorData.load();
        final sensorDataList = geo.sensorData.toList();
        sensorDataList.sort((a, b) => compareSensorsByCanonicalOrder(
          a.title, a.attribute, b.title, b.attribute,
        ));
        geo.sensorData.clear();
        geo.sensorData.addAll(sensorDataList);
      }

      return geolocations;
    });
  }

  Future<void> deleteAllGeolocations() async {
    await isarProvider.runWriteTxn((isar) async {
      await isar.geolocationDatas.clear();
    });
  }
}
