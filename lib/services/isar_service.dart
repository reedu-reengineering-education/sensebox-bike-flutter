// File: lib/services/isar_service.dart
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/utils/isar_utils.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';

class IsarService {
  final IsarProvider isarProvider;
  final TrackService trackService;
  final GeolocationService geolocationService;
  final SensorService sensorService;

  IsarService({required this.isarProvider})
      : trackService = TrackService(isarProvider: isarProvider),
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
    final senseBox = await getSelectedSenseBoxOrThrow();
    final geolocationDataList =
        await geolocationService.getGeolocationDataByTrackId(trackId);
    final List<String> sensorDataLines = [];

    for (var geoData in geolocationDataList) {
      final data = await sensorService.getSensorDataByGeolocationId(geoData.id);
      sensorDataLines.addAll(
        data.map((sensor) {
          final sensorId = findSensorIdByData(sensor, senseBox.sensors ?? []);
          return formatOpenSenseMapCsvLine(sensorId, sensor.value, geoData);
        }),
      );
    }

    // Convert the enriched sensor data to CSV lines
    final csvContent = sensorDataLines.join('\n');
    final filePath = await _saveCsvFile(track, csvContent);

    return filePath;
  }

  Future<String> exportTrackToCsv(int trackId) async {
    final track = await _getTrackOrThrow(trackId);
    final geolocationDataList =
        await geolocationService.getGeolocationDataByTrackId(trackId);
    final sensorDataByGeolocation = <int, List<SensorData>>{};

    for (var geoData in geolocationDataList) {
      final sensorData =
          await sensorService.getSensorDataByGeolocationId(geoData.id);
      sensorDataByGeolocation[geoData.id] = sensorData;
    }

    final sensorTitles = collectSensorTitles(sensorDataByGeolocation);
    final headers = buildCsvHeaders(sensorTitles);
    final csvData = <List<String>>[
      headers,
      ...buildCsvRows(
          geolocationDataList, sensorDataByGeolocation, sensorTitles),
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
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
