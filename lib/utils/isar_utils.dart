import 'dart:convert';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SenseBox> getSelectedSenseBoxOrThrow() async {
  final prefs = await SharedPreferences.getInstance();
  final selectedSenseBoxJson = prefs.getString('selectedSenseBox');

  if (selectedSenseBoxJson == null) {
    throw Exception("No selected senseBox found");
  }
  final senseBox = SenseBox.fromJson(jsonDecode(selectedSenseBoxJson));

  if (senseBox.sensors == null || senseBox.sensors!.isEmpty) {
    throw Exception("SenseBox has no sensors");
  }

  return senseBox;
}

String formatOpenSenseMapCsvLine(String? sensorId, double? value, GeolocationData geoData) {
  return [
    sensorId,
    value?.toString() ?? '',
    '${geoData.timestamp.toIso8601String()}Z',
    geoData.longitude.toString(),
    geoData.latitude.toString(),
    'null'
  ].join(',');
}

Set<List<String?>> collectSensorTitles(Map<int, List<SensorData>> sensorDataByGeolocation) {
  const separator = '%%';
  final sensorTitlesSet = <String>{};
  for (var sensorData in sensorDataByGeolocation.values) {
    for (var sensor in sensorData) {
      sensorTitlesSet
          .add('${sensor.title}$separator${sensor.attribute ?? ""}');
    }
  }
  return sensorTitlesSet.map((str) {
    var parts = str.split(separator);
    return [
      parts[0].isEmpty ? null : parts[0],
      parts[1].isEmpty ? null : parts[1]
    ];
  }).toSet();
}

List<String> buildCsvHeaders(Set<List<String?>> sensorTitles) {
  return [
    'timestamp',
    'latitude',
    'longitude',
    ...sensorTitles.map((title) {
      if (title[1] == null) return title[0]!;
      return title.join('_').replaceAll(".", "_");
    }),
  ];
}

Map<String, double?> organizeSensorData(List<SensorData> sensorDataList,{String separator = '%%'}) {
  final sensorMap = <String, double?>{};

  for (var sensorData in sensorDataList) {
    sensorMap['${sensorData.title}$separator${sensorData.attribute}'] =
        sensorData.value;
  }

  return sensorMap;
}

List<List<String>> buildCsvRows(
  List<GeolocationData> geolocationDataList,
  Map<int, List<SensorData>> sensorDataByGeolocation,
  Set<List<String?>> sensorTitles,
) {
  const separator = '%%';
  return geolocationDataList.map((geoData) {
    final sensorData = sensorDataByGeolocation[geoData.id] ?? [];
    if (sensorData.isEmpty) return null;
    final sensorMap = organizeSensorData(sensorData, separator: separator);
    final values = sensorTitles.map((title) => sensorMap['${title[0]}$separator${title[1]}']).toList();
    return [
      geoData.timestamp.toString(),
      geoData.latitude.toString(),
      geoData.longitude.toString(),
      ...values.map((value) => value?.toString() ?? ''),
    ];
  }).whereType<List<String>>().toList();
}