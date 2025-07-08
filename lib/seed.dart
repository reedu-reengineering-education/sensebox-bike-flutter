import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/sensors/distance_sensor.dart';
import 'package:sensebox_bike/sensors/finedust_sensor.dart';
import 'package:sensebox_bike/sensors/humidity_sensor.dart';
import 'package:sensebox_bike/sensors/overtaking_prediction_sensor.dart';
import 'package:sensebox_bike/sensors/surface_classification_sensor.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';

Future<void> seedIsarWithSampleData(IsarService isarService) async {
  final random = Random();
  const int numTracks = 5;
  const int minDurationSec = 2 * 60; // 2 minutes
  const int maxDurationSec = 60 * 60; // 1 hour
  const int geolocationsPerMinute = 10; // 10 geolocations per minute
  const double geolocationsPerSecond = geolocationsPerMinute / 60.0; // ≈ 0.1667 per second
  final now = DateTime.now();

  // Sensor types and their value ranges
  final sensorSpecs = [
    {
      'title': 'temperature',
      'characteristicUuid': TemperatureSensor.sensorCharacteristicUuid,
      'attribute': null,
      'min': 15.0,
      'max': 30.0,
      'unit': '°C',
    },
    {
      'title': 'humidity',
      'characteristicUuid': HumiditySensor.sensorCharacteristicUuid,
      'attribute': null,
      'min': 0.0,
      'max': 100.0,
      'unit': '%',
    },
    {
      'title': 'finedust',
      'characteristicUuid': FinedustSensor.sensorCharacteristicUuid,
      'attribute': 'pm1',
      'min': 5.0,
      'max': 50.0,
      'unit': 'µg/m³',
    },
    {
      'title': 'finedust',
      'characteristicUuid': FinedustSensor.sensorCharacteristicUuid,
      'attribute': 'pm2.5',
      'min': 5.0,
      'max': 50.0,
      'unit': 'µg/m³',
    },
    {
      'title': 'finedust',
      'characteristicUuid': FinedustSensor.sensorCharacteristicUuid,
      'attribute': 'pm4',
      'min': 5.0,
      'max': 50.0,
      'unit': 'µg/m³',
    },
    {
      'title': 'finedust',
      'characteristicUuid': FinedustSensor.sensorCharacteristicUuid,
      'attribute': 'pm10',
      'min': 5.0,
      'max': 50.0,
      'unit': 'µg/m³',
    },
    {
      'title': 'overtaking',
      'characteristicUuid': OvertakingPredictionSensor.sensorCharacteristicUuid,
      'attribute': null,
      'min': 0.0,
      'max': 100.0,
      'unit': '%',
    },
    {
      'title': 'distance',
      'characteristicUuid': DistanceSensor.sensorCharacteristicUuid,
      'attribute': null,
      'min': 0.0,
      'max': 200.0,
      'unit': 'cm',
    },
    {
      'title': 'surface_classification',
      'characteristicUuid': SurfaceClassificationSensor.sensorCharacteristicUuid,
      'attribute': 'asphalt',
      'min': 0.0,
      'max': 100.0,
      'unit': '%',
    },
    {
      'title': 'surface_classification',
      'characteristicUuid': SurfaceClassificationSensor.sensorCharacteristicUuid,
      'attribute': 'sett',
      'min': 0.0,
      'max': 100.0,
      'unit': '%',
    },
    {
      'title': 'surface_classification',
      'characteristicUuid': SurfaceClassificationSensor.sensorCharacteristicUuid,
      'attribute': 'compacted',
      'min': 0.0,
      'max': 100.0,
      'unit': '%',
    },
    {
      'title': 'surface_classification',
      'characteristicUuid': SurfaceClassificationSensor.sensorCharacteristicUuid,
      'attribute': 'paving',
      'min': 0.0,
      'max': 100.0,
      'unit': '%',
    },
    {
      'title': 'surface_classification',
      'characteristicUuid': SurfaceClassificationSensor.sensorCharacteristicUuid,
      'attribute': 'standing',
      'min': 0.0,
      'max': 100.0,
      'unit': '%',
    },
    {
      'title': 'gps',
      'characteristicUuid': SurfaceClassificationSensor.sensorCharacteristicUuid,
      'attribute': 'speed',
      'min': 0.0,
      'max': 5.0,
      'unit': 'm/s',
    },
  ];

  final isar = await isarService.isarProvider.getDatabase();
  for (int t = 0; t < numTracks; t++) {
    await isar.writeTxn(() async {
      debugPrint('//// Seeding track $t of $numTracks');
      // Random start time within last 30 days
      final startOffset = random.nextInt(30 * 24 * 60 * 60); // seconds
      final startTime = now.subtract(Duration(seconds: startOffset));
      final durationSec =
          minDurationSec + random.nextInt(maxDurationSec - minDurationSec + 1);
      final numGeolocations = (durationSec * geolocationsPerSecond).round();

      // Generate a random start lat/lon (e.g., somewhere in Germany)
      double baseLat = 52.5 + random.nextDouble() * 1.0; // 52.5 - 53.5
      double baseLon = 13.0 + random.nextDouble() * 1.0; // 13.0 - 14.0
      double lat = baseLat;
      double lon = baseLon;

      final track = TrackData();
      await isar.trackDatas.put(track);
      debugPrint('//// Track ID: ${track.id}');
      List<GeolocationData> geos = [];
      for (int i = 0; i < numGeolocations; i++) {
        lat += (random.nextDouble() - 0.5) * 0.01;
        lon += (random.nextDouble() - 0.5) * 0.01;
        final timestamp = startTime.add(Duration(seconds: (i * (60 ~/ geolocationsPerMinute))));
        final speed = (sensorSpecs.last['min']! as double) +
            random.nextDouble() *
                ((sensorSpecs.last['max']! as double) -
                    (sensorSpecs.last['min']! as double));

        final geo = GeolocationData()
          ..latitude = lat
          ..longitude = lon
          ..speed = speed
          ..timestamp = timestamp;
        geo.track.value = track;
        geos.add(geo);
      }
      await isar.geolocationDatas.putAll(geos);
      track.geolocations.addAll(geos);
      debugPrint('//// Geolocations: ${geos.length}');
      // For each geolocation, generate sensor data
      List<SensorData> allSensors = [];
      for (final geo in geos) {
        // Surface percentages: generate 5 randoms, normalize to 100
        final surfaceRaw = List.generate(5, (_) => random.nextDouble());
        final surfaceSum = surfaceRaw.reduce((a, b) => a + b);
        final surfacePercentages =
            surfaceRaw.map((v) => v / surfaceSum * 100).toList();
        int surfaceIdx = 0;

        for (final spec in sensorSpecs) {
          double value;
          if (spec['title'].toString().startsWith('surface_classification')) {
            value = surfacePercentages[surfaceIdx++];
          } else {
            value = (spec['min']! as double) +
                random.nextDouble() *
                    ((spec['max']! as double) - (spec['min']! as double));
          }
          final sensor = SensorData()
            ..characteristicUuid = spec['characteristicUuid'] as String
            ..title = (spec['title'] as String).trim()
            ..attribute = (spec['attribute'] as String?)?.trim()
            ..value = value;
          sensor.geolocationData.value = geo;
          allSensors.add(sensor);
        }
      }
      await isar.sensorDatas.putAll(allSensors);
      debugPrint('//// Sensors: ${allSensors.length}');
      // Link sensors to geolocations
      for (int i = 0, geoIdx = 0; geoIdx < geos.length; geoIdx++) {
        final geo = geos[geoIdx];
        geo.sensorData.addAll(allSensors.skip(i).take(sensorSpecs.length));
        i += sensorSpecs.length;
      }
      debugPrint('//// Sensors linked to geolocations');
      // Save all links
      await track.geolocations.save();
      for (final geo in geos) {
        await geo.track.save();
        await geo.sensorData.save();
      }
      for (final sensor in allSensors) {
        await sensor.geolocationData.save();
      }
      debugPrint('//// Track $t seeded successfully');
    });
  }
}
