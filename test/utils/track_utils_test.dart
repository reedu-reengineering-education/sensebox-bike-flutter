import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
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
        final tempSensor1 = createMockSensorData(geo1);
        tempSensor1.title = 'temperature';
        tempSensor1.value = 25.0;
        tempSensor1.attribute = 'Celsius';

        final tempSensor2 = createMockSensorData(geo2);
        tempSensor2.title = 'temperature';
        tempSensor2.value = 26.0;
        tempSensor2.attribute = 'Celsius';

        final humiditySensor = createMockSensorData(geo1);
        humiditySensor.title = 'humidity';
        humiditySensor.value = 60.0;
        humiditySensor.attribute = 'Percent';

        // Save everything to the database
        await isar.writeTxn(() async {
          await isar.geolocationDatas.put(geo1);
          await isar.geolocationDatas.put(geo2);
          await isar.sensorDatas.put(tempSensor1);
          await isar.sensorDatas.put(tempSensor2);
          await isar.sensorDatas.put(humiditySensor);

          // Link the data
          await geo1.track.save();
          await geo2.track.save();
          await tempSensor1.geolocationData.save();
          await tempSensor2.geolocationData.save();
          await humiditySensor.geolocationData.save();
        });

        // Load the geolocations with their sensor data
        final loadedGeo1 = await isar.geolocationDatas.get(geo1.id);
        final loadedGeo2 = await isar.geolocationDatas.get(geo2.id);

        // Load the sensor data links
        await loadedGeo1!.sensorData.load();
        await loadedGeo2!.sensorData.load();

        final result = getAllUniqueSensorData([loadedGeo1, loadedGeo2]);

        expect(result.length, 3);
        expect(result.any((s) => s.title == 'temperature' && s.value == 25.0),
            isTrue);
        expect(result.any((s) => s.title == 'temperature' && s.value == 26.0),
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
}
