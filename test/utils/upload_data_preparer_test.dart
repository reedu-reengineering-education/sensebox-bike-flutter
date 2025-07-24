import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/utils/upload_data_preparer.dart';

void main() {
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
  });
} 