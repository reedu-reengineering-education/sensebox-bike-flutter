// File: lib/services/isar_service/geolocation_service.dart
import 'dart:async';
import 'dart:math';

import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:isar_community/isar.dart';

const _sensorPreloadBatchSize = 100;

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
    return await isar.geolocationDatas
        .where()
        .filter()
        .track((q) => q.idEqualTo(trackId))
        .sortByTimestamp()
        .findAll();
  }

  /// Loads sensors from the first [sampleSize] geolocations and returns one
  /// representative [SensorData] per discovered sensor type.
  Future<List<SensorData>> discoverAvailableSensorsFromGeolocations(
    List<GeolocationData> geolocations, {
    int sampleSize = discoverSensorSampleSize,
  }) async {
    if (geolocations.isEmpty) return [];

    final sample = geolocations.take(sampleSize).toList();
    final isar = await isarProvider.getDatabase();
    final uniqueByKey = <String, SensorData>{};

    await isar.txn(() async {
      for (final geo in sample) {
        await geo.sensorData.load();
        for (final sensor in geo.sensorData) {
          final key = buildCanonicalSensorKey(sensor.title, sensor.attribute);
          uniqueByKey.putIfAbsent(key, () => sensor);
        }
      }
    });

    final sensors = uniqueByKey.values.toList()
      ..sort((a, b) => compareSensorsByCanonicalOrder(
            a.title,
            a.attribute,
            b.title,
            b.attribute,
          ));
    return sensors;
  }

  Future<List<GeolocationData>> getGeolocationDataWithPreloadedSensors(
      int trackId) async {
    final isar = await isarProvider.getDatabase();
    final geolocations = await isar.geolocationDatas
        .where()
        .filter()
        .track((q) => q.idEqualTo(trackId))
        .findAll();

    for (var start = 0; start < geolocations.length; start += _sensorPreloadBatchSize) {
      final end = min(start + _sensorPreloadBatchSize, geolocations.length);
      await isar.txn(() async {
        for (var i = start; i < end; i++) {
          await _preloadSensorDataForGeolocation(geolocations[i]);
        }
      });
    }

    return geolocations;
  }

  Future<void> _preloadSensorDataForGeolocation(GeolocationData geo) async {
    await geo.sensorData.load();
    final sensorDataList = geo.sensorData.toList();
    sensorDataList.sort((a, b) => compareSensorsByCanonicalOrder(
          a.title,
          a.attribute,
          b.title,
          b.attribute,
        ));
    geo.sensorData.clear();
    geo.sensorData.addAll(sensorDataList);
  }

  Future<void> deleteAllGeolocations() async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      await isar.geolocationDatas.clear();
    });
  }
}
