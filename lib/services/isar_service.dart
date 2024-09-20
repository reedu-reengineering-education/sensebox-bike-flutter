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

class IsarService {
  final TrackService trackService = TrackService();
  final GeolocationService geolocationService = GeolocationService();
  final SensorService sensorService = SensorService();

  // Additional high-level methods that require coordination between services

  Future<String> exportTrackToCsv(int trackId) async {
    final track = await trackService.getTrackById(trackId);
    if (track == null) {
      throw Exception("Track not found");
    }

    final geolocationDataList =
        await geolocationService.getGeolocationDataByTrackId(trackId);
    final sensorDataByGeolocation = <int, List<SensorData>>{};

    for (var geoData in geolocationDataList) {
      final sensorData =
          await sensorService.getSensorDataByGeolocationId(geoData.id);
      sensorDataByGeolocation[geoData.id] = sensorData;
    }

    String separator = '%%';
    Set<String> sensorTitlesSet = {};
    for (var sensorData in sensorDataByGeolocation.values) {
      for (var sensor in sensorData) {
        String key = '${sensor.title}$separator${sensor.attribute ?? ""}';
        sensorTitlesSet.add(key);
      }
    }

    List<List<String?>> sensorTitles = sensorTitlesSet.map((str) {
      var parts = str.split(separator);
      return [
        parts[0].isEmpty ? null : parts[0],
        parts[1].isEmpty ? null : parts[1]
      ];
    }).toList();

    final csvData = <List<String>>[];

    final sensorHeaders = sensorTitles.map((title) {
      if (title[1] == null) {
        return title[0]!;
      }
      return title.join('_').replaceAll(".", "_");
    }).toList();

    final headers = ['timestamp', 'latitude', 'longitude', ...sensorHeaders];

    csvData.add(headers);

    for (var geoData in geolocationDataList) {
      final sensorData = sensorDataByGeolocation[geoData.id] ?? [];
      if (sensorData.isEmpty) {
        continue;
      }

      final sensorMap = _organizeSensorData(sensorData, separator: separator);

      // get sensor values in the same order as the headers
      final values = sensorTitles.map((title) {
        return sensorMap['${title[0]}$separator${title[1]}'];
      }).toList();

      final row = [
        geoData.timestamp.toString(),
        geoData.latitude.toString(),
        geoData.longitude.toString(),
        ...values.map((value) => value?.toString() ?? ''),
      ];

      csvData.add(row);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    final filePath = await _saveCsvFile(track, csvString);

    return filePath;
  }

  Map<String, double?> _organizeSensorData(List<SensorData> sensorDataList,
      {String separator = '%%'}) {
    final sensorMap = <String, double?>{};

    for (var sensorData in sensorDataList) {
      sensorMap['${sensorData.title}$separator${sensorData.attribute}'] =
          sensorData.value;
    }

    return sensorMap;
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
}
