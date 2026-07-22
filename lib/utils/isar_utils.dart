import 'dart:convert';

import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
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
  // Handle both old format (local time) and new format (UTC time)
  String timestampString;
  if (geoData.timestamp.isUtc) {
    // Timestamp is already in UTC, just format it
    timestampString = '${geoData.timestamp.toIso8601String()}';
  } else {
    // Timestamp is in local time, convert to UTC
    timestampString = '${geoData.timestamp.toUtc().toIso8601String()}';
  }
  
  return [
    sensorId,
    value?.toStringAsFixed(2) ?? '', // format value to 2 decimal places
    timestampString,
    geoData.longitude.toString(),
    geoData.latitude.toString(),
    'null'
  ].join(',');
}

Set<List<String?>> collectSensorTitles(Map<int, List<SensorData>> sensorDataByGeolocation) {
  const separator = '%%';
  final sensorTitlesSet = <String>{};
  final characteristicUuidsByKey = <String, Set<String>>{};

  for (var sensorData in sensorDataByGeolocation.values) {
    for (var sensor in sensorData) {
      final key = '${sensor.title}$separator${sensor.attribute ?? ""}';
      sensorTitlesSet.add(key);
      characteristicUuidsByKey
          .putIfAbsent(key, () => <String>{})
          .add(sensor.characteristicUuid);
    }
  }

  for (final entry in characteristicUuidsByKey.entries) {
    if (entry.value.length > 1) {
      final parts = entry.key.split(separator);
      final title = parts[0];
      final attribute = parts.length > 1 ? parts[1] : '';
      sensorTitlesSet.add('sensor_${title}$separator$attribute');
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

List<List<String?>> sortSensorTitlesByCanonicalOrder(Set<List<String?>> sensorTitles) {
  final titlesList = sensorTitles.toList();
  titlesList.sort((a, b) {
    final sensorKeyA = buildCanonicalSensorKey(a[0] ?? '', a[1]);
    final sensorKeyB = buildCanonicalSensorKey(b[0] ?? '', b[1]);
    
    final canonicalComparison = compareSensorKeysByCanonicalOrder(sensorKeyA, sensorKeyB);
    if (canonicalComparison != 0) {
      return canonicalComparison;
    }
    
    return sensorKeyA.compareTo(sensorKeyB);
  });
  
  return titlesList;
}

List<List<String?>> collectAndSortSensorTitles(
    Map<int, List<SensorData>> sensorDataByGeolocation) {
  return sortSensorTitlesByCanonicalOrder(
      collectSensorTitles(sensorDataByGeolocation));
}

List<String> buildCsvHeaders(List<List<String?>> sensorTitles) {
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

Map<String, double?> organizeSensorData(
  List<SensorData> sensorDataList, {
  String separator = '%%',
  Set<String>? keysWithSecondaryColumn,
}) {
  final sensorMap = <String, double?>{};

  final sorted = List<SensorData>.from(sensorDataList)..sort((a, b) => a.id.compareTo(b.id));
  final entriesByKey = <String, List<SensorData>>{};

  for (var sensorData in sorted) {
    final key = '${sensorData.title}$separator${sensorData.attribute ?? ''}';
    entriesByKey.putIfAbsent(key, () => <SensorData>[]).add(sensorData);
  }

  for (final entry in entriesByKey.entries) {
    final key = entry.key;
    final sensorsForKey = entry.value;

    final firstIdByUuid = <String, int>{};
    final latestValueByUuid = <String, double?>{};

    for (final sensor in sensorsForKey) {
      firstIdByUuid.putIfAbsent(sensor.characteristicUuid, () => sensor.id);
      latestValueByUuid[sensor.characteristicUuid] = sensor.value;
    }

    final orderedUuids = firstIdByUuid.keys.toList()
      ..sort((a, b) => firstIdByUuid[a]!.compareTo(firstIdByUuid[b]!));

    if (orderedUuids.isEmpty) {
      continue;
    }

    final primaryUuid = orderedUuids.first;
    sensorMap[key] = latestValueByUuid[primaryUuid];

    final needsSecondary =
        (keysWithSecondaryColumn ?? const <String>{}).contains(key);
    if (needsSecondary && orderedUuids.length > 1) {
      final secondaryUuid = orderedUuids[1];
      final parts = key.split(separator);
      final title = parts[0];
      final attribute = parts.length > 1 ? parts[1] : '';
      sensorMap['sensor_$title$separator$attribute'] =
          latestValueByUuid[secondaryUuid];
    }
  }

  return sensorMap;
}

List<List<String>> buildCsvRows(
  List<GeolocationData> geolocationDataList,
  Map<int, List<SensorData>> sensorDataByGeolocation,
  List<List<String?>> sensorTitles,
) {
  const separator = '%%';
  final keysWithSecondaryColumn = sensorTitles
      .where((title) => (title[0] ?? '').startsWith('sensor_'))
      .map((title) {
    final baseTitle = (title[0] ?? '').replaceFirst('sensor_', '');
    return '$baseTitle$separator${title[1] ?? ''}';
  }).toSet();

  return geolocationDataList
      .map((geoData) {
        final sensorData = sensorDataByGeolocation[geoData.id] ?? [];
        if (sensorData.isEmpty) return null;
        final sensorMap = organizeSensorData(
          sensorData,
          separator: separator,
          keysWithSecondaryColumn: keysWithSecondaryColumn,
        );
        final values = sensorTitles
            .map((title) => MapEntry(
                title[0],
                sensorMap['${title[0]}$separator${title[1] ?? ''}']))
            .toList();

        final timestampUtc = geoData.timestamp.isUtc
            ? geoData.timestamp
            : geoData.timestamp.toUtc();
        final timestampString = timestampUtc.toIso8601String();

        return [
          timestampString,
          geoData.latitude.toString(),
          geoData.longitude.toString(),
          ...values.map((entry) {
            final isGps = entry.key?.toLowerCase() == 'sensor_gps';
            return isGps
                ? (entry.value?.toStringAsFixed(5) ?? '')
                : (entry.value?.toStringAsFixed(2) ?? '');
          }),
        ];
      })
      .whereType<List<String>>()
      .toList();
}