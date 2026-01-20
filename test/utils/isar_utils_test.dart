import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/utils/isar_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final geoData = GeolocationData()
    ..id = 1
    ..timestamp = DateTime.utc(2025, 5, 14, 12, 0, 0)
    ..latitude = 52.52
    ..longitude = 13.405;

  final tempSensorData = SensorData()
    ..id = 1
    ..title = 'temperature'
    ..attribute = '°C'
    ..value = 22.5;

  final surfaceSensorData = SensorData()
    ..id = 2
    ..title = 'surface_classification_compacted'
    ..attribute = '%'
    ..value = 60.0;

  final overtakingSensorData = SensorData()
    ..id = 3
    ..title = 'distance'
    ..attribute = 'cm'
    ..value = 100.0;

  group('formatOpenSenseMapCsvLine', () {
    test('formats all fields correctly', () {
      final result = formatOpenSenseMapCsvLine('sensor-1', 22.5, geoData);
      expect(
        result,
        'sensor-1,22.50,2025-05-14T12:00:00.000Z,13.405,52.52,null',
      );
    });
  });

  group('organizeSensorData', () {
    test('returns correct map for sensor data list', () {
      final sensorDataList = [tempSensorData, surfaceSensorData, overtakingSensorData];
      final result = organizeSensorData(sensorDataList);

      expect(result, {
        'temperature%%°C': 22.5,
        'surface_classification_compacted%%%': 60.0,
        'distance%%cm': 100.0,
      });
    });

    test('returns empty map for empty list', () {
      expect(organizeSensorData([]), {});
    });
  });

  group('collectSensorTitles', () {
    test('collects unique sensor titles and attributes', () {
      final Map<int, List<SensorData>> sensorDataByGeolocation = {
        1: [tempSensorData, surfaceSensorData],
        2: [tempSensorData, overtakingSensorData],
      };
      final result = collectSensorTitles(sensorDataByGeolocation);

      expect(
        result,
        {
          ['temperature', '°C'],
          ['surface_classification_compacted', '%'],
          ['distance', 'cm'],
        },
      );
    });

    test('returns empty set for empty map', () {
      expect(collectSensorTitles({}), <List<String?>>{});
    });
  });

  group('buildCsvHeaders', () {
    test('builds headers with and without attributes', () {
      final sensorTitles = [
        ['temperature', null],
        ['surface_classification', 'compacted'],
        ['finedust', 'pm1'],
      ];
      final result = buildCsvHeaders(sensorTitles);
      expect(
        result,
        [
          'timestamp',
          'latitude',
          'longitude',
          'temperature',
          'surface_classification_compacted',
          'finedust_pm1',
        ],
      );
    });

    test('returns base headers for empty list', () {
      expect(buildCsvHeaders([]), ['timestamp', 'latitude', 'longitude']);
    });
  });

  group('buildCsvRows', () {
    test('builds correct rows for geolocation and sensor data', () {
      final geoData1 = GeolocationData()
        ..id = 1
        ..timestamp = DateTime.utc(2025, 5, 14, 12, 0, 0)
        ..latitude = 52.52
        ..longitude = 13.405;
      final geoData2 = GeolocationData()
        ..id = 2
        ..timestamp = DateTime.utc(2025, 5, 14, 12, 5, 0)
        ..latitude = 52.53
        ..longitude = 13.406;

      final tempSensorData1 = SensorData()
        ..id = 1
        ..title = 'temperature'
        ..attribute = '°C'
        ..value = 22.5;
      final tempSensorData2 = SensorData()
        ..id = 2
        ..title = 'temperature'
        ..attribute = '°C'
        ..value = 23.0;
      final humiditySensorData = SensorData()
        ..id = 3
        ..title = 'humidity'
        ..attribute = '%'
        ..value = 60.0;

      final geolocationDataList = [geoData1, geoData2];
      final Map<int, List<SensorData>> sensorDataByGeolocation = {
        1: [tempSensorData1, humiditySensorData],
        2: [tempSensorData2],
      };
      final sensorTitles = [
        ['temperature', '°C'],
        ['humidity', '%'],
      ];

      final rows = buildCsvRows(geolocationDataList, sensorDataByGeolocation, sensorTitles);

      expect(rows, [
        [
          '2025-05-14T12:00:00.000Z',
          '52.52',
          '13.405',
          '22.50',
          '60.00',
        ],
        [
          '2025-05-14T12:05:00.000Z',
          '52.53',
          '13.406',
          '23.00',
          '',
        ],
      ]);
    });

    test('skips rows with no sensor data', () {
      final geoData1 = GeolocationData()
        ..id = 1
        ..timestamp = DateTime.utc(2025, 5, 14, 12, 0, 0)
        ..latitude = 52.52
        ..longitude = 13.405;
      final geoData2 = GeolocationData()
        ..id = 2
        ..timestamp = DateTime.utc(2025, 5, 14, 12, 5, 0)
        ..latitude = 52.53
        ..longitude = 13.406;

      final tempSensorData1 = SensorData()
        ..id = 1
        ..title = 'temperature'
        ..attribute = '°C'
        ..value = 22.5;

      final geolocationDataList = [geoData1, geoData2];
      final Map<int, List<SensorData>> sensorDataByGeolocation = {
        1: [tempSensorData1],
        2: [],
      };
      final sensorTitles = [
        ['temperature', '°C'],
      ];

      final rows = buildCsvRows(geolocationDataList, sensorDataByGeolocation, sensorTitles);

      expect(rows, [
        [
          '2025-05-14T12:00:00.000Z',
          '52.52',
          '13.405',
          '22.50',
        ],
      ]);
    });
  });

  group('getSelectedSenseBoxOrThrow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('throws if no selectedSenseBox found', () async {
      expect(
        () => getSelectedSenseBoxOrThrow(),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('No selected senseBox found'))),
      );
    });

    test('throws if selectedSenseBox has no sensors', () async {
      SharedPreferences.setMockInitialValues(
          {'selectedSenseBox': '{"sensors":[], "grouptag": ["test"]}'});
      expect(
        () => getSelectedSenseBoxOrThrow(),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('SenseBox has no sensors'))),
      );
    });

    test('returns SenseBox if present and has sensors', () async {
      SharedPreferences.setMockInitialValues({
        'selectedSenseBox':
            '{"sensors":[{"id":"1","title":"Temperature","unit":"°C"}], "grouptag": ["test"]}'
      });
      final senseBox = await getSelectedSenseBoxOrThrow();
      expect(senseBox, isA<SenseBox>());
      expect(senseBox.sensors, isNotEmpty);
      expect(senseBox.sensors!.first.title, 'Temperature');
    });
  });

  group('sortSensorTitlesByCanonicalOrder', () {
    test('sorts surface classification sensors in correct order', () {
      final sensorTitles = {
        ['surface_classification', 'sett'],
        ['surface_classification', 'asphalt'],
        ['surface_classification', 'standing'],
        ['surface_classification', 'compacted'],
        ['surface_classification', 'paving'],
      };

      final result = sortSensorTitlesByCanonicalOrder(sensorTitles);

      expect(result.length, 5);
      // Verify correct order: asphalt, compacted, paving, sett, standing
      expect(result[0][1], 'asphalt');
      expect(result[1][1], 'compacted');
      expect(result[2][1], 'paving');
      expect(result[3][1], 'sett');
      expect(result[4][1], 'standing');
    });

    test('sorts sensors according to canonical order when mixed with other sensor types',
        () {
      final sensorTitles = {
        ['humidity', null],
        ['surface_classification', 'sett'],
        ['temperature', null],
        ['surface_classification', 'asphalt'],
        ['finedust', 'pm10'],
        ['surface_classification', 'compacted'],
      };

      final result = sortSensorTitlesByCanonicalOrder(sensorTitles);

      expect(result.length, 6);
      expect(result[0][0], 'temperature');
      expect(result[1][0], 'humidity');
      expect(result[2][1], 'asphalt');
      expect(result[3][1], 'compacted');
      expect(result[4][1], 'sett');
      expect(result[5][0], 'finedust');
    });

    test('handles sensors not in canonical order by sorting alphabetically', () {
      final sensorTitles = {
        ['unknown_sensor', null],
        ['temperature', null],
        ['another_unknown', 'attribute'],
      };

      final result = sortSensorTitlesByCanonicalOrder(sensorTitles);

      expect(result.length, 3);
      expect(result[0][0], 'temperature');
      expect(result[1][0], 'another_unknown');
      expect(result[2][0], 'unknown_sensor');
    });
  });

  group('collectAndSortSensorTitles', () {
    test('collects and sorts sensor titles in canonical order', () {
      final sensorData1 = SensorData()
        ..id = 1
        ..title = 'humidity'
        ..attribute = null
        ..value = 60.0;
      final sensorData2 = SensorData()
        ..id = 2
        ..title = 'surface_classification'
        ..attribute = 'sett'
        ..value = 10.0;
      final sensorData3 = SensorData()
        ..id = 3
        ..title = 'temperature'
        ..attribute = null
        ..value = 25.0;
      final sensorData4 = SensorData()
        ..id = 4
        ..title = 'surface_classification'
        ..attribute = 'asphalt'
        ..value = 80.0;

      final Map<int, List<SensorData>> sensorDataByGeolocation = {
        1: [sensorData1, sensorData2],
        2: [sensorData3, sensorData4],
      };

      final result = collectAndSortSensorTitles(sensorDataByGeolocation);

      expect(result.length, 4);
      expect(result[0][0], 'temperature');
      expect(result[1][0], 'humidity');
      expect(result[2][0], 'surface_classification');
      expect(result[2][1], 'asphalt');
      expect(result[3][0], 'surface_classification');
      expect(result[3][1], 'sett');
    });

    test('handles empty map', () {
      expect(collectAndSortSensorTitles({}), isEmpty);
    });
  });
}
