// File: lib/services/isar_service.dart
import 'package:ble_app/models/geolocation_data.dart';
import 'package:ble_app/models/sensor_data.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = _initDB();
  }

  Future<Isar> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    return await Isar.open(
      [GeolocationDataSchema, SensorDataSchema], // Schemas for the collections
      directory: dir.path,
    );
  }

  Future<int> saveGeolocationData(GeolocationData geolocationData) async {
    final isar = await db;
    return await isar.writeTxn(() async {
      return await isar.geolocationDatas.put(geolocationData);
    });
  }

  Future<int> saveSensorData(SensorData sensorData) async {
    final isar = await db;
    return await isar.writeTxn(() async {
      int sensorDataId = await isar.sensorDatas.put(sensorData);
      await sensorData.geolocationData.save();
      return sensorDataId;
    });
  }

  Future<List<GeolocationData>> getGeolocationData() async {
    final isar = await db;
    return await isar.geolocationDatas.where().findAll();
  }

  Future<List<SensorData>> getSensorData() async {
    final isar = await db;
    return await isar.sensorDatas.where().findAll();
  }

  Future<void> deleteAllData() async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.geolocationDatas.clear();
      await isar.sensorDatas.clear();
    });
  }
}
