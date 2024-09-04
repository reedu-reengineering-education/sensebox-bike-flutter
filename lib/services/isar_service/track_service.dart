// File: lib/services/isar_service/track_service.dart
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:isar/isar.dart';

class TrackService {
  final IsarProvider _isarProvider = IsarProvider();

  Future<Id> saveTrack(TrackData track) async {
    final isar = await _isarProvider.getDatabase();
    return await isar.writeTxn(() async {
      return await isar.trackDatas.put(track);
    });
  }

  Future<TrackData?> getTrackById(int id) async {
    final isar = await _isarProvider.getDatabase();
    return await isar.trackDatas.get(id);
  }

  Future<List<TrackData>> getAllTracks() async {
    final isar = await _isarProvider.getDatabase();
    return await isar.trackDatas.where().findAll();
  }
}
