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

    test(
        'prepareDataFromGroupedData converts acceleration multi-value sensors correctly',
        () {
      final accelerationXSensor = Sensor()
        ..id = 'accelerationXSensorId'
        ..title = 'Acceleration X';
      final accelerationYSensor = Sensor()
        ..id = 'accelerationYSensorId'
        ..title = 'Acceleration Y';
      final accelerationZSensor = Sensor()
        ..id = 'accelerationZSensorId'
        ..title = 'Acceleration Z';
      final speedSensor = Sensor()
        ..id = 'speedSensorId'
        ..title = 'Speed';
      final senseBox = SenseBox(sensors: [
        accelerationXSensor,
        accelerationYSensor,
        accelerationZSensor,
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
          'acceleration': [0.1, 0.2, 0.3], // X, Y, Z
        },
      };

      final result =
          preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);

      // Should have speed data and 3 acceleration entries
      expect(result.length, 4);

      // Check acceleration entries
      final accelerationEntries =
          result.keys.where((k) => k.contains('acceleration')).toList();
      expect(accelerationEntries.length, 3);

      // Check X
      final xKey = accelerationEntries
          .firstWhere((k) => k.contains('accelerationXSensorId'));
      final xEntry = result[xKey] as Map<String, dynamic>;
      expect(xEntry['sensor'], 'accelerationXSensorId');
      expect(xEntry['value'], '0.10');

      // Check Y
      final yKey = accelerationEntries
          .firstWhere((k) => k.contains('accelerationYSensorId'));
      final yEntry = result[yKey] as Map<String, dynamic>;
      expect(yEntry['sensor'], 'accelerationYSensorId');
      expect(yEntry['value'], '0.20');

      // Check Z
      final zKey = accelerationEntries
          .firstWhere((k) => k.contains('accelerationZSensorId'));
      final zEntry = result[zKey] as Map<String, dynamic>;
      expect(zEntry['sensor'], 'accelerationZSensorId');
      expect(zEntry['value'], '0.30');
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

      // Should have speed data and temperature data, but not unknown sensor
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