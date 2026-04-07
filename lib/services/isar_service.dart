// File: lib/services/isar_service.dart
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/services/storage/selected_sensebox_storage.dart';
import 'package:sensebox_bike/services/track_export_service.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';

class IsarService {
  final IsarProvider isarProvider;
  final TrackService trackService;
  final GeolocationService geolocationService;
  final SensorService sensorService;
  final SelectedSenseBoxStorage selectedSenseBoxStorage;
  final TrackExportService trackExportService;

  IsarService({
    required this.isarProvider,
    required this.selectedSenseBoxStorage,
    required this.trackExportService,
  })  : trackService = TrackService(isarProvider: isarProvider),
        geolocationService = GeolocationService(isarProvider: isarProvider),
        sensorService = SensorService(isarProvider: isarProvider);

  Future<TrackData> _getTrackOrThrow(int trackId) async {
    final track = await trackService.getTrackById(trackId);
    if (track == null) throw Exception("Track not found");
    return track;
  }

  // Additional high-level methods that require coordination between services
  Future<String> exportTrackToCsvInOpenSenseMapFormat(int trackId) async {
    final track = await _getTrackOrThrow(trackId);
    final csvContent = await trackExportService.buildOpenSenseMapCsvContent(
      trackId: trackId,
      geolocationService: geolocationService,
      sensorService: sensorService,
      selectedSenseBoxStorage: selectedSenseBoxStorage,
    );
    final filePath = await _saveCsvFile(track, csvContent);

    return filePath;
  }

  Future<String> exportTrackToCsv(int trackId) async {
    final track = await _getTrackOrThrow(trackId);
    final csvString = await trackExportService.buildCsvContent(
      trackId: trackId,
      geolocationService: geolocationService,
      sensorService: sensorService,
    );
    final filePath = await _saveCsvFile(track, csvString);

    return filePath;
  }

  Future<String> _saveCsvFile(TrackData track, String csvString) async {
    final directory = await getApplicationDocumentsDirectory();

    if (track.geolocations.isEmpty) {
      throw Exception("Track has no geolocations");
    }

    String formattedTimestamp = DateFormat('yyyy-MM-dd_HH-mm')
        .format(track.geolocations.first.timestamp);

    String trackName = "senseBox_bike_$formattedTimestamp";

    final filePath = '${directory.path}/$trackName.csv';
    final file = File(filePath);

    await file.writeAsString(csvString);
    return filePath;
  }

  Future<void> deleteAllData() async {
    try {
      await trackService.deleteAllTracks();
      await geolocationService.deleteAllGeolocations();
      await sensorService.deleteAllSensorData();

      print("All data has been successfully deleted.");
    } catch (e) {
      print("Error while deleting all data: $e");
      throw Exception("Failed to delete all data.");
    }
  }

  Future<List<TrackData>> getTracksPaginated(
      {required int offset, required int limit}) {
    return trackService.getTracksPaginated(offset: offset, limit: limit);
  }
}
