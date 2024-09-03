// File: lib/services/isar_service.dart
import 'package:ble_app/models/geolocation_data.dart';
import 'package:ble_app/models/sensor_data.dart';
import 'package:ble_app/models/track_data.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class IsarService {
  static final IsarService _instance = IsarService._internal();
  late Future<Isar> db;

  factory IsarService() {
    return _instance;
  }

  IsarService._internal() {
    db = _initDB();
  }

  Future<Isar> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    return await Isar.open(
      [
        TrackDataSchema,
        GeolocationDataSchema,
        SensorDataSchema
      ], // Schemas for the collections
      directory: dir.path,
    );
  }

  Future<Id> saveTrack(TrackData track) async {
    final isar = await db;
    return await isar.writeTxn(() async {
      return await isar.trackDatas.put(track);
    });
  }

  Future<Id> saveGeolocationData(GeolocationData geolocationData) async {
    final isar = await db;
    return await isar.writeTxn(() async {
      Id geoDataId = await isar.geolocationDatas.put(geolocationData);
      await geolocationData.track.save();
      return geoDataId;
    });
  }

  Future<Id> saveSensorData(SensorData sensorData) async {
    final isar = await db;
    return await isar.writeTxn(() async {
      Id sensorDataId = await isar.sensorDatas.put(sensorData);
      await sensorData.geolocationData.save();
      return sensorDataId;
    });
  }

  Future<List<TrackData>> geoTrackData() async {
    final isar = await db;
    return await isar.trackDatas.where().findAll();
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
      await isar.trackDatas.clear();
      await isar.geolocationDatas.clear();
      await isar.sensorDatas.clear();
    });
  }
}
