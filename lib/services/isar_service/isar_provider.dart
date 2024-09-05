// File: lib/services/isar_service/isar_provider.dart
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';

class IsarProvider {
  static final IsarProvider _instance = IsarProvider._internal();
  late Future<Isar> db;

  factory IsarProvider() {
    return _instance;
  }

  IsarProvider._internal() {
    db = _initDB();
  }

  Future<Isar> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    return await Isar.open(
      [
        TrackDataSchema,
        GeolocationDataSchema,
        SensorDataSchema,
      ],
      directory: dir.path,
    );
  }

  Future<Isar> getDatabase() => db;
}