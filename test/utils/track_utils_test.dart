import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import '../test_helpers.dart';

void main() {
  group('calculateBounds', () {
    test('returns world bounds for empty list', () {
      final bounds = calculateBounds([]);
      expect(bounds.southwest.coordinates.lng, -180);
      expect(bounds.southwest.coordinates.lat, -90);
      expect(bounds.northeast.coordinates.lng, 180);
      expect(bounds.northeast.coordinates.lat, 90);
    });

    test('returns minDelta bounds for single point', () {
      final geo = GeolocationData()
        ..latitude= 10.0
        ..longitude= 20.0
        ..timestamp= DateTime(1970, 1, 1);
      final bounds = calculateBounds([geo], minDelta: 0.002);
      expect(bounds.southwest.coordinates.lat, closeTo(10.0 - 0.001, 1e-9));
      expect(bounds.northeast.coordinates.lat, closeTo(10.0 + 0.001, 1e-9));
      expect(bounds.southwest.coordinates.lng, closeTo(20.0 - 0.001, 1e-9));
      expect(bounds.northeast.coordinates.lng, closeTo(20.0 + 0.001, 1e-9));
    });

    test('returns correct bounds for two distinct points', () {
      final geo1 = GeolocationData()
        ..latitude= 10.0
        ..longitude= 20.0
        ..timestamp= DateTime(1970, 1, 1);
      final geo2 = GeolocationData()
        ..latitude= 11.0
        ..longitude= 21.0
        ..timestamp= DateTime(1970, 1, 1);
      final bounds = calculateBounds([geo1, geo2], minDelta: 0.002);

      expect(bounds.southwest.coordinates.lat, 10.0);
      expect(bounds.northeast.coordinates.lat, 11.0);
      expect(bounds.southwest.coordinates.lng, 20.0);
      expect(bounds.northeast.coordinates.lng, 21.0);
    });

    test('applies minDelta if points are very close', () {
      final geo1 = GeolocationData()
        ..latitude= 10.0
        ..longitude= 20.0
        ..timestamp= DateTime(1970, 1, 1);
      final geo2 = GeolocationData()
        ..latitude= 10.0005
        ..longitude= 20.0005
        ..timestamp= DateTime(1970, 1, 1);
      final bounds = calculateBounds([geo1, geo2]);
      
      expect(
        bounds.northeast.coordinates.lat - bounds.southwest.coordinates.lat,
        closeTo(0.002, 1e-9),
      );
      expect(
        bounds.northeast.coordinates.lng - bounds.southwest.coordinates.lng,
        closeTo(0.002, 1e-9),
      );
    });
  });

  group('getAllUniqueSensorData', () {
    test('returns empty list for empty geolocations', () {
      final result = getAllUniqueSensorData([]);
      expect(result, isEmpty);
    });

    test('returns empty list for geolocations with no sensor data', () {
      final geo1 = GeolocationData()
        ..latitude = 10.0
        ..longitude = 20.0
        ..timestamp = DateTime(1970, 1, 1);
      final geo2 = GeolocationData()
        ..latitude = 11.0
        ..longitude = 21.0
        ..timestamp = DateTime(1970, 1, 1);

      final result = getAllUniqueSensorData([geo1, geo2]);
      expect(result, isEmpty);
    });

    test('returns all unique sensor data from geolocations with Isar setup',
        () async {
      final isar = await initializeInMemoryIsar();

      try {
        // Create a track
        final track = createMockTrackData();
        await isar.writeTxn(() async {
          await isar.trackDatas.put(track);
        });

        // Create geolocations with sensor data
        final geo1 = createMockGeolocationData(track);
        final geo2 = createMockGeolocationData(track);

        // Create sensor data
        final tempSensor = createMockSensorData(geo1);
        tempSensor.title = 'temperature';
        tempSensor.value = 25.0;
        tempSensor.attribute = 'Celsius';

        final humiditySensor = createMockSensorData(geo1);
        humiditySensor.title = 'humidity';
        humiditySensor.value = 60.0;
        humiditySensor.attribute = 'Percent';
        
        // Explicitly add sensors to geolocation's sensorData collection
        geo1.sensorData.add(tempSensor);
        geo1.sensorData.add(humiditySensor);

        // Save everything to the database
        await isar.writeTxn(() async {
          // First save the geolocations
          await isar.geolocationDatas.put(geo1);
          await isar.geolocationDatas.put(geo2);
          
          // Then save the sensor data
          await isar.sensorDatas.put(tempSensor);
          await isar.sensorDatas.put(humiditySensor);

          // Link the data
          await geo1.track.save();
          await geo2.track.save();
          await tempSensor.geolocationData.save();
          await humiditySensor.geolocationData.save();
          
          // Save the geolocations again to persist the sensor data links
          await isar.geolocationDatas.put(geo1);
          await isar.geolocationDatas.put(geo2);
        });
        
        // Load the geolocations with their sensor data
        final loadedGeo1 = await isar.geolocationDatas.get(geo1.id);
        final loadedGeo2 = await isar.geolocationDatas.get(geo2.id);

        // Load the sensor data links
        await loadedGeo1!.sensorData.load();
        await loadedGeo2!.sensorData.load();

        final result = getAllUniqueSensorData([loadedGeo1, loadedGeo2]);

        // Should have 2 unique sensor data entries (1 temperature + 1 humidity)
        expect(result.length, 2);
        expect(result.any((s) => s.title == 'temperature' && s.value == 25.0),
            isTrue);
        expect(result.any((s) => s.title == 'humidity' && s.value == 60.0),
            isTrue);
      } finally {
        await isar.close();
      }
    });
  });

  group('sensorColorForValue', () {
    test('returns green for value at min', () {
      final color = sensorColorForValue(value: 10, min: 10, max: 20);
      expect(color, Colors.green);
    });

    test('returns red for value at max', () {
      final color = sensorColorForValue(value: 20, min: 10, max: 20);
      expect(color, Colors.red);
    });

    test('returns orange for value at midpoint', () {
      final color = sensorColorForValue(value: 15, min: 10, max: 20);
      // Compare color value as Color.lerp may not return exactly Colors.orange
      expect(color.value, Colors.orange.value);
    });

    test('returns grey if min and max are zero', () {
      final color = sensorColorForValue(value: 0, min: 0, max: 0);
      expect(color, Colors.grey);
    });
  });
  // TBD: tests fun locally, but not on CI
  // TBD: fix this later
  // group('trackName', () {
  //   test('returns formatted start and end time from geolocations', () async {
  //     final track = createMockTrackData();
  //     await isar.writeTxn(() async {
  //       await isar.trackDatas.put(track);
  //     });

  //     final start = createMockGeolocationData(track);
  //     start.track.value = track;
  //     await isar.writeTxn(() async {
  //       await isar.geolocationDatas.put(start);
  //       await start.track.save();
  //     });
  //     final end = createMockGeolocationData(track);
  //     end.track.value = track;
  //     await isar.writeTxn(() async {
  //       await isar.geolocationDatas.put(end);
  //       await end.track.save();
  //     });

  //     final expected =
  //         '${DateFormat('dd-MM-yyyy HH:mm').format(start.timestamp)} - ${DateFormat('HH:mm').format(end.timestamp)}';
  //     expect(trackName(track), expected);
  //   });

  //   test('throws if geolocations is empty and no error message provided',
  //       () async {
  //     final track = createMockTrackData();
  //     await isar.writeTxn(() async {
  //       await isar.trackDatas.put(track);
  //     });

  //     expect(trackName(track), "No data available");
  //   });

  //   test('returns error message, if geolocations is empty', () async {
  //     final track = createMockTrackData();
  //     final errorMessage = "Custom error message";

  //     expect(trackName(track, errorMessage: errorMessage), errorMessage);
  //   });

  //   test(
  //       'returns formatted start and end time, if geolocations has only one element',
  //       () async {
  //     final track = createMockTrackData();
  //     final start = createMockGeolocationData(track);
  //     start.track.value = track;
  //     await isar.writeTxn(() async {
  //       await isar.geolocationDatas.put(start);
  //       await start.track.save();
  //     });

  //     final expected =
  //         '${DateFormat('dd-MM-yyyy HH:mm').format(start.timestamp)} - ${DateFormat('HH:mm').format(start.timestamp)}';

  //     expect(trackName(track), expected);
  //   });
  // });

  group('UploadDataPreparer Tests', () {
    test('getMatchingSensor finds correct sensor by title', () {
      final tempSensor = Sensor()
        ..id = 'tempSensorId'
        ..title = 'Temperature';
      final senseBox = SenseBox(sensors: [tempSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final result = preparer.getMatchingSensor('Temperature');

      expect(result, tempSensor);
    });

    test('getMatchingSensor finds sensor case-insensitively', () {
      final tempSensor = Sensor()
        ..id = 'tempSensorId'
        ..title = 'Temperature';
      final senseBox = SenseBox(sensors: [tempSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final result = preparer.getMatchingSensor('temperature');

      expect(result, tempSensor);
    });

    test('getMatchingSensor returns null for non-existent sensor', () {
      final tempSensor = Sensor()
        ..id = 'tempSensorId'
        ..title = 'Temperature';
      final senseBox = SenseBox(sensors: [tempSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final result = preparer.getMatchingSensor('NonExistent');

      expect(result, null);
    });

    test('getMatchingSensor returns null for empty title', () {
      final tempSensor = Sensor()
        ..id = 'tempSensorId'
        ..title = 'Temperature';
      final senseBox = SenseBox(sensors: [tempSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final result = preparer.getMatchingSensor('');

      expect(result, null);
    });

    test('getSpeedSensorId returns correct speed sensor ID', () {
      final speedSensor = Sensor()
        ..id = 'speedSensorId'
        ..title = 'Speed';
      final senseBox = SenseBox(sensors: [speedSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final result = preparer.getSpeedSensorId();

      expect(result, 'speedSensorId');
    });

    test('getSpeedSensorId throws exception when speed sensor not found', () {
      final senseBox = SenseBox(sensors: []);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      expect(() => preparer.getSpeedSensorId(), throwsStateError);
    });

    test(
        'prepareDataFromGroupedData handles surface_classification with Standing sensor correctly',
        () {
      final surfaceAsphaltSensor = Sensor()
        ..id = 'surfaceAsphaltSensorId'
        ..title = 'Surface Asphalt';
      final surfaceSettSensor = Sensor()
        ..id = 'surfaceSettSensorId'
        ..title = 'Surface Sett';
      final surfaceCompactedSensor = Sensor()
        ..id = 'surfaceCompactedSensorId'
        ..title = 'Surface Compacted';
      final surfacePavingSensor = Sensor()
        ..id = 'surfacePavingSensorId'
        ..title = 'Surface Paving';
      final standingSensor = Sensor()
        ..id = 'standingSensorId'
        ..title = 'Standing';
      final speedSensor = Sensor()
        ..id = 'speedSensorId'
        ..title = 'Speed';
      final senseBox = SenseBox(sensors: [
        surfaceAsphaltSensor,
        surfaceSettSensor,
        surfaceCompactedSensor,
        surfacePavingSensor,
        standingSensor,
        speedSensor
      ]);
      final preparer = UploadDataPreparer(senseBox: senseBox);
      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'surface_classification': [10.0, 15.0, 20.0, 25.0, 30.0], // 5 values
        },
      };

      final result =
          preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);

      final surfaceEntries = result.keys
          .where((k) => k.contains('surface') || k.contains('standing'))
          .toList();
      expect(surfaceEntries.length, 5);

      final standingEntries =
          result.keys.where((k) => k.contains('standingSensorId')).toList();
      expect(standingEntries.length, 1);

      final standingKey = standingEntries.first;
      final standingEntry = result[standingKey] as Map<String, dynamic>;
      expect(standingEntry['value'], '30.00');
      expect(standingEntry['sensor'], 'standingSensorId');
    });

    test('prepareDataFromGroupedData converts single-value sensors correctly',
        () {
      final tempSensor = Sensor()
        ..id = 'tempSensorId'
        ..title = 'Temperature';
      final speedSensor = Sensor()
        ..id = 'speedSensorId'
        ..title = 'Speed';
      final senseBox = SenseBox(sensors: [tempSensor, speedSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [22.5],
        },
      };

      final result =
          preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);

      // Should have speed data and temperature data
      expect(result.length, 2);

      // Check speed data
      final speedKey = result.keys.firstWhere((k) => k.startsWith('speed_'));
      final speedEntry = result[speedKey] as Map<String, dynamic>;
      expect(speedEntry['sensor'], 'speedSensorId');
      expect(speedEntry['value'], '5.00');
      expect(speedEntry['location']['lat'], 10.0);
      expect(speedEntry['location']['lng'], 20.0);
      expect(speedEntry['createdAt'], '2024-01-01T12:00:00.000Z');

      // Check temperature data
      final tempKey =
          result.keys.firstWhere((k) => k.startsWith('tempSensorId'));
      final tempEntry = result[tempKey] as Map<String, dynamic>;
      expect(tempEntry['sensor'], 'tempSensorId');
      expect(tempEntry['value'], '22.50');
      expect(tempEntry['location']['lat'], 10.0);
      expect(tempEntry['location']['lng'], 20.0);
      expect(tempEntry['createdAt'], '2024-01-01T12:00:00.000Z');
    });

    test(
        'prepareDataFromGroupedData converts finedust multi-value sensors correctly',
        () {
      final finedustPM1Sensor = Sensor()
        ..id = 'finedustPM1SensorId'
        ..title = 'Finedust PM1';
      final finedustPM25Sensor = Sensor()
        ..id = 'finedustPM25SensorId'
        ..title = 'Finedust PM2.5';
      final finedustPM4Sensor = Sensor()
        ..id = 'finedustPM4SensorId'
        ..title = 'Finedust PM4';
      final finedustPM10Sensor = Sensor()
        ..id = 'finedustPM10SensorId'
        ..title = 'Finedust PM10';
      final speedSensor = Sensor()
        ..id = 'speedSensorId'
        ..title = 'Speed';
      final senseBox = SenseBox(sensors: [
        finedustPM1Sensor,
        finedustPM25Sensor,
        finedustPM4Sensor,
        finedustPM10Sensor,
        speedSensor
      ]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'finedust': [1.5, 2.5, 3.5, 4.5], // PM1, PM2.5, PM4, PM10
        },
      };

      final result =
          preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);

      // Should have speed data and 4 finedust entries
      expect(result.length, 5);

      // Check finedust entries
      final finedustEntries =
          result.keys.where((k) => k.contains('finedust')).toList();
      expect(finedustEntries.length, 4);

      // Check PM1
      final pm1Key =
          finedustEntries.firstWhere((k) => k.contains('finedustPM1SensorId'));
      final pm1Entry = result[pm1Key] as Map<String, dynamic>;
      expect(pm1Entry['sensor'], 'finedustPM1SensorId');
      expect(pm1Entry['value'], '1.50');

      // Check PM2.5
      final pm25Key =
          finedustEntries.firstWhere((k) => k.contains('finedustPM25SensorId'));
      final pm25Entry = result[pm25Key] as Map<String, dynamic>;
      expect(pm25Entry['sensor'], 'finedustPM25SensorId');
      expect(pm25Entry['value'], '2.50');

      // Check PM4
      final pm4Key =
          finedustEntries.firstWhere((k) => k.contains('finedustPM4SensorId'));
      final pm4Entry = result[pm4Key] as Map<String, dynamic>;
      expect(pm4Entry['sensor'], 'finedustPM4SensorId');
      expect(pm4Entry['value'], '3.50');

      // Check PM10
      final pm10Key =
          finedustEntries.firstWhere((k) => k.contains('finedustPM10SensorId'));
      final pm10Entry = result[pm10Key] as Map<String, dynamic>;
      expect(pm10Entry['sensor'], 'finedustPM10SensorId');
      expect(pm10Entry['value'], '4.50');
    });



    test('prepareDataFromGroupedData handles multiple geolocations correctly',
        () {
      final tempSensor = Sensor()
        ..id = 'tempSensorId'
        ..title = 'Temperature';
      final speedSensor = Sensor()
        ..id = 'speedSensorId'
        ..title = 'Speed';
      final senseBox = SenseBox(sensors: [tempSensor, speedSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
        GeolocationData()
          ..latitude = 10.1
          ..longitude = 20.1
          ..speed = 6.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 10),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [22.5],
        },
        gpsBuffer[1]: {
          'temperature': [23.5],
        },
      };

      final result =
          preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);

      // Should have 2 speed entries and 2 temperature entries
      expect(result.length, 4);

      // Check speed entries
      final speedEntries =
          result.keys.where((k) => k.startsWith('speed_')).toList();
      expect(speedEntries.length, 2);

      // Check temperature entries
      final tempEntries =
          result.keys.where((k) => k.startsWith('tempSensorId')).toList();
      expect(tempEntries.length, 2);

      // Check first temperature entry
      final tempKey1 =
          tempEntries.firstWhere((k) => k.contains('2024-01-01T12:00:00.000Z'));
      final tempEntry1 = result[tempKey1] as Map<String, dynamic>;
      expect(tempEntry1['value'], '22.50');
      expect(tempEntry1['location']['lat'], 10.0);
      expect(tempEntry1['location']['lng'], 20.0);

      // Check second temperature entry
      final tempKey2 =
          tempEntries.firstWhere((k) => k.contains('2024-01-01T12:00:10.000Z'));
      final tempEntry2 = result[tempKey2] as Map<String, dynamic>;
      expect(tempEntry2['value'], '23.50');
      expect(tempEntry2['location']['lat'], 10.1);
      expect(tempEntry2['location']['lng'], 20.1);
    });

    test('prepareDataFromGroupedData handles empty grouped data correctly', () {
      final speedSensor = Sensor()
        ..id = 'speedSensorId'
        ..title = 'Speed';
      final senseBox = SenseBox(sensors: [speedSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = <GeolocationData, Map<String, List<double>>>{};

      final result =
          preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);

      // Should have only speed data
      expect(result.length, 1);

      final speedKey = result.keys.first;
      expect(speedKey.startsWith('speed_'), true);

      final speedEntry = result[speedKey] as Map<String, dynamic>;
      expect(speedEntry['sensor'], 'speedSensorId');
      expect(speedEntry['value'], '5.00');
    });

    test('prepareDataFromGroupedData handles empty GPS buffer correctly', () {
      final tempSensor = Sensor()
        ..id = 'tempSensorId'
        ..title = 'Temperature';
      final senseBox = SenseBox(sensors: [tempSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final gpsBuffer = <GeolocationData>[];
      final groupedData = <GeolocationData, Map<String, List<double>>>{};

      final result =
          preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);

      // Should return empty result
      expect(result.isEmpty, true);
    });

    test('prepareDataFromGroupedData handles unknown sensor types gracefully',
        () {
      final tempSensor = Sensor()
        ..id = 'tempSensorId'
        ..title = 'Temperature';
      final speedSensor = Sensor()
        ..id = 'speedSensorId'
        ..title = 'Speed';
      final senseBox = SenseBox(sensors: [tempSensor, speedSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.0
          ..longitude = 20.0
          ..speed = 5.0
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'unknown_sensor': [42.0],
          'temperature': [22.5],
        },
      };

      final result =
          preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);

      // Should have speed data and temperature data, but unknown sensor is skipped
      expect(result.length, 2);

      // Check that temperature data is still processed
      final tempEntries =
          result.keys.where((k) => k.startsWith('tempSensorId')).toList();
      expect(tempEntries.length, 1);

      // Check that unknown sensor is not included
      final unknownEntries =
          result.keys.where((k) => k.contains('unknown')).toList();
      expect(unknownEntries.length, 0);
    });

    test('prepareDataFromGroupedData formats decimal values correctly', () {
      final tempSensor = Sensor()
        ..id = 'tempSensorId'
        ..title = 'Temperature';
      final speedSensor = Sensor()
        ..id = 'speedSensorId'
        ..title = 'Speed';
      final senseBox = SenseBox(sensors: [tempSensor, speedSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);

      final gpsBuffer = [
        GeolocationData()
          ..latitude = 10.123456
          ..longitude = 20.654321
          ..speed = 5.678
          ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0),
      ];

      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [22.123456],
        },
      };

      final result =
          preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);

      // Check temperature value formatting
      final tempKey =
          result.keys.firstWhere((k) => k.startsWith('tempSensorId'));
      final tempEntry = result[tempKey] as Map<String, dynamic>;
      expect(tempEntry['value'],
          '22.12'); // Should be formatted to 2 decimal places

      // Check speed value formatting
      final speedKey = result.keys.firstWhere((k) => k.startsWith('speed_'));
      final speedEntry = result[speedKey] as Map<String, dynamic>;
      expect(speedEntry['value'],
          '5.68'); // Should be formatted to 2 decimal places

      // Check location precision (should preserve original precision)
      expect(tempEntry['location']['lat'], 10.123456);
      expect(tempEntry['location']['lng'], 20.654321);
    });
  });
}
