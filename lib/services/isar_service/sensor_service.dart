// File: lib/services/isar_service/sensor_service.dart
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:isar/isar.dart';

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
    return await isar.sensorDatas.where().filter().geolocationData((q) {
      return q.idEqualTo(geolocationId);
    }).findAll();
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

  Future<void> deleteAllSensorData() async {
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      await isar.sensorDatas.clear();
    });
  }

  Future<void> saveSensorDataBatch(List<SensorData> batch) async {
    if (batch.isEmpty) return;
    final isar = await isarProvider.getDatabase();
    await isar.writeTxn(() async {
      for (final sensor in batch) {
        await isar.sensorDatas.put(sensor);
        await sensor.geolocationData.save();
      }
    });
  }
}
