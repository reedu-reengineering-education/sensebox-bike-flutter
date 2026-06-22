import 'dart:convert';
import 'dart:io';

import 'package:sensebox_bike/models/sensor_catalog_entry.dart';
import 'package:sensebox_bike/services/sensor_catalog_registry.dart';

final mockSensorCatalogJson = [
  {
    'label': 'Temperature',
    'key': 'temperature',
    'characteristicUuid': '2cdf2174-35be-fdc4-4ca2-6fd173f8b3a8',
    'icon': 'osem-thermometer',
    'unit': '°C',
    'sensorType': 'HDC1080',
  },
  {
    'label': 'Rel. Humidity',
    'key': 'humidity',
    'characteristicUuid': '772df7ec-8cdc-4ea9-86af-410abe0ba257',
    'icon': 'osem-humidity',
    'unit': '%',
    'sensorType': 'HDC1080',
  },
  {
    'label': 'Overtaking Distance',
    'key': 'distance',
    'title': 'Overtaking Distance',
    'characteristicUuid': 'b3491b60-c0f3-4306-a30d-49c91f37a62b',
    'icon': 'osem-shock',
    'unit': 'cm',
    'sensorType': 'VL53L8CX',
  },
];

List<SensorCatalogEntry> parseMockSensorCatalog() {
  return mockSensorCatalogJson
      .map((item) => SensorCatalogEntry.fromJson(item))
      .toList();
}

void setupMockSensorCatalog() {
  SensorCatalogRegistry.setEntries(parseMockSensorCatalog());
}

void setupSensorCatalogFromRepo() {
  final file = File('data/sensors.json');
  final json = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  SensorCatalogRegistry.setEntries(
    json
        .map((item) => SensorCatalogEntry.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

void clearMockSensorCatalog() {
  SensorCatalogRegistry.clear();
}
