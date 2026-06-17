// File: lib/services/isar_service/sensor_service.dart
import 'dart:math';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:isar_community/isar.dart';

const _sensorAttachBatchSize = 100;

class SensorService {
  final IsarProvider isarProvider;

  SensorService({required this.isarProvider});

  Future<Id> saveSensorData(SensorData sensorData) async {
    final isar = await isarProvider.getDatabase();
    return await isar.writeTxn(() async {
      Id sensorDataId = await isar.sensorDatas.put(sensorData);
      await sensorData.geolocationData.save();
      return sensorDataId;
    });
  }

  Future<List<SensorData>> getSensorData() async {
    final isar = await isarProvider.getDatabase();
    return await isar.sensorDatas.where().findAll();
  }

  Future<List<SensorData>> getSensorDataByGeolocationId(
      int geolocationId) async {
    final isar = await isarProvider.getDatabase();
    final sensorData = await isar.sensorDatas.where().filter().geolocationData((q) {
      return q.idEqualTo(geolocationId);
    }).findAll();
    
    sensorData.sort((a, b) => compareSensorsByCanonicalOrder(
      a.title, a.attribute, b.title, b.attribute,
    ));
    
    return sensorData;
  }

  Future<List<SensorData>> getSensorDataByTrackId(int trackId) async {
    final isar = await isarProvider.getDatabase();

    var geolocationData =
        await isar.geolocationDatas.where().filter().track((q) {
      return q.idEqualTo(trackId);
    }).findAll();

    var sensorData = <SensorData>[];
    for (var geoData in geolocationData) {
      var sensorDataList = await isar.sensorDatas
          .where()
          .filter()
          .geolocationData((q) => q.idEqualTo(geoData.id))
          .findAll();
      sensorData.addAll(sensorDataList);
    }

    return sensorData;
  }

  Future<void> attachSensorTypeToGeolocations(
    List<GeolocationData> geolocations,
    String sensorTypeKey,
  ) async {
    if (geolocations.isEmpty) return;

    final parts = parseCanonicalSensorKey(sensorTypeKey);
    final isar = await isarProvider.getDatabase();

    for (var start = 0; start < geolocations.length; start += _sensorAttachBatchSize) {
      final end = min(start + _sensorAttachBatchSize, geolocations.length);
      await isar.txn(() async {
        for (var i = start; i < end; i++) {
          final geo = geolocations[i];
          final sensors = await _getSensorsForGeolocation(
            isar,
            geo.id,
            parts.title,
            parts.attribute,
          );
          await geo.sensorData.load();
          geo.sensorData.clear();
          geo.sensorData.addAll(sensors);
        }
      });
    }
  }

  Future<List<SensorData>> _getSensorsForGeolocation(
    Isar isar,
    Id geolocationId,
    String title,
    String? attribute,
  ) async {
    final sensors = await isar.sensorDatas.where().filter().geolocationData((q) {
      return q.idEqualTo(geolocationId);
    }).findAll();

    return sensors
        .where((sensor) => sensor.title == title && sensor.attribute == attribute)
        .toList();
  }

  Future<void> deleteAllSensorData() async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      await isar.sensorDatas.clear();
    });
  }

  Future<void> saveSensorDataBatch(List<SensorData> batch) async {
    if (batch.isEmpty) return;
    final isar = await isarProvider.getDatabase();
    
    try {
      await isar.writeTxn(() async {
        for (final sensor in batch) {
          try {
            await isar.sensorDatas.put(sensor);
            await sensor.geolocationData.save();
          } catch (e) {
            // Continue with other sensors in the batch
          }
        }
      });
    } catch (e) {
      rethrow; // Re-throw to let the caller handle it
    }
  }
}
