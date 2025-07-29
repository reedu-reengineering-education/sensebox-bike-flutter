import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/utils/isar_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final geoData = GeolocationData()
    ..id = 1
    ..timestamp = DateTime.parse('2025-05-14T12:00:00')
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
        'sensor-1,22.50,2025-05-14T10:00:00.000Z,13.405,52.52,null',
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
  });

  group('collectSensorTitles', () {
    test('collects unique sensor titles and attributes', () {
      final Map<int, List<SensorData>> sensorDataByGeolocation = {
        1: [ tempSensorData, surfaceSensorData ],
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
  });

  group('buildCsvHeaders', () {
    test('builds headers with and without attributes', () {
      final sensorTitles = {
        ['temperature', null],
        ['surface_classification', 'compacted'],
        ['finedust', 'pm1'],
      };
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
  });

  group('buildCsvRows', () {
    test('builds correct rows for geolocation and sensor data', () {
      final geoData1 = GeolocationData()
        ..id = 1
        ..timestamp = DateTime.parse('2025-05-14T12:00:00')
        ..latitude = 52.52
        ..longitude = 13.405;
      final geoData2 = GeolocationData()
        ..id = 2
        ..timestamp = DateTime.parse('2025-05-14T12:05:00')
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
      final sensorTitles = {
        ['temperature', '°C'],
        ['humidity', '%'],
      };

      final rows = buildCsvRows(geolocationDataList, sensorDataByGeolocation, sensorTitles);

      expect(rows, [
        [
          '2025-05-14 12:00:00.000',
          '52.52',
          '13.405',
          '22.50',
          '60.00',
        ],
        [
          '2025-05-14 12:05:00.000',
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
        ..timestamp = DateTime.parse('2025-05-14T12:00:00')
        ..latitude = 52.52
        ..longitude = 13.405;
      final geoData2 = GeolocationData()
        ..id = 2
        ..timestamp = DateTime.parse('2025-05-14T12:05:00')
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
      final sensorTitles = {
        ['temperature', '°C'],
      };

      final rows = buildCsvRows(geolocationDataList, sensorDataByGeolocation, sensorTitles);

      expect(rows, [
        [
          '2025-05-14 12:00:00.000',
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
}