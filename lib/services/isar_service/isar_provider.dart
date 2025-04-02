// File: lib/services/isar_service/isar_provider.dart
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';

class IsarProvider {
  static final IsarProvider _instance = IsarProvider._internal();
  static Isar? _isar;
  factory IsarProvider() => _instance;
  IsarProvider._internal();

  Future<Isar> get db async {
    if (_isar != null && _isar!.isOpen) return _isar!;
    
    return _isar = await _initDB();
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

  /// Added back `getDatabase` method for direct access
  Future<Isar> getDatabase() async {
    return await db;
  }

  /// Close the database connection
  Future<void> close() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
    }
  }
}
