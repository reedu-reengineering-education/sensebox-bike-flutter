// File: lib/services/isar_service/isar_provider.dart
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';

class IsarProvider {
  static final IsarProvider _instance = IsarProvider._internal();
  static Isar? _isar;
  factory IsarProvider() => _instance;
  IsarProvider._internal();

  Future<void> _writeChain = Future.value();

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

  /// Serializes all write transactions so only one [writeTxn] runs at a time.
  Future<T> runWriteTxn<T>(Future<T> Function(Isar isar) action) async {
    final operation = _writeChain.then((_) async {
      final isar = await getDatabase();
      return isar.writeTxn(() => action(isar));
    });
    _writeChain = operation.then((_) {}, onError: (_) {});
    return operation;
  }

  Future<Isar> getDatabase() async {
    return await db;
  }

  Future<void> close() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
    }
    _isar = null;
    _writeChain = Future.value();
  }
}
