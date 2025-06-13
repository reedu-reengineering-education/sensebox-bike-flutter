// File: lib/services/isar_service/sensor_service.dart
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:isar/isar.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SensorService {
  final IsarProvider _isarProvider = IsarProvider();

  Future<Id> saveSensorData(SensorData sensorData) async {
    final isar = await _isarProvider.getDatabase();
    return await isar.writeTxn(() async {
      Id sensorDataId = await isar.sensorDatas.put(sensorData);
      await sensorData.geolocationData.save();
      return sensorDataId;
    });
  }

  Future<List<SensorData>> getSensorData() async {
    final isar = await _isarProvider.getDatabase();
    return await isar.sensorDatas.where().findAll();
  }

  Future<List<SensorData>> getSensorDataByGeolocationId(
      int geolocationId) async {
    final isar = await _isarProvider.getDatabase();
    return await isar.sensorDatas.where().filter().geolocationData((q) {
      return q.idEqualTo(geolocationId);
    }).findAll();
  }

  Future<List<SensorData>> getSensorDataByTrackId(int trackId) async {
try {
      final isar = await _isarProvider.getDatabase();

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
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return [];
    }
  }
}
