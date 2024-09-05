// File: lib/services/isar_service/geolocation_service.dart
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:isar/isar.dart';

class GeolocationService {
  final IsarProvider _isarProvider = IsarProvider();

  Future<Id> saveGeolocationData(GeolocationData geolocationData) async {
    final isar = await _isarProvider.getDatabase();
    return await isar.writeTxn(() async {
      Id geoDataId = await isar.geolocationDatas.put(geolocationData);
      await geolocationData.track.save();
      return geoDataId;
    });
  }

  Future<List<GeolocationData>> getGeolocationData() async {
    final isar = await _isarProvider.getDatabase();
    return await isar.geolocationDatas.where().findAll();
  }

  Future<List<GeolocationData>> getGeolocationDataByTrackId(int trackId) async {
    final isar = await _isarProvider.getDatabase();
    return await isar.geolocationDatas.where().filter().track((q) {
      return q.idEqualTo(trackId);
    }).findAll();
  }
}
