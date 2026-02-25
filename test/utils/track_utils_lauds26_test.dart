import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/utils/track_utils.dart';

void main() {
  group('UploadDataPreparer LAUDS 26', () {
        test('handles distance sensors', () {
          final sensors = [
            Sensor()..id = '7'..title = 'Distance Left',
            Sensor()..id = '8'..title = 'Distance Right',
          ];
          final senseBox = SenseBox(sensors: sensors);
          final preparer = UploadDataPreparer(senseBox: senseBox);
          final gpsBuffer = [GeolocationData()
            ..latitude = 10.0
            ..longitude = 20.0
            ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0)];
          final groupedData = {
            gpsBuffer[0]: {
              'distance': [123.4],
              'distance_right': [234.5],
            },
          };
          final result = preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);
          expect(result.length, 2);
          expect(result.values.any((e) => e['sensor'] == '7'), isTrue);
          expect(result.values.any((e) => e['sensor'] == '8'), isTrue);
          final left = result.values.firstWhere((e) => e['sensor'] == '7');
          final right = result.values.firstWhere((e) => e['sensor'] == '8');
          expect(left['value'], '123.40');
          expect(right['value'], '234.50');
        });
    test('handles finedust sensors', () {
      final sensors = [
        Sensor()..id = '2'..title = 'Finedust PM1',
        Sensor()..id = '3'..title = 'Finedust PM2.5',
        Sensor()..id = '4'..title = 'Finedust PM4',
        Sensor()..id = '5'..title = 'Finedust PM10',
      ];
      final senseBox = SenseBox(sensors: sensors);
      final preparer = UploadDataPreparer(senseBox: senseBox);
      final gpsBuffer = [GeolocationData()
        ..latitude = 10.0
        ..longitude = 20.0
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0)];
      final groupedData = {
        gpsBuffer[0]: {
          'finedust': [1.1, 2.2, 3.3, 4.4],
        },
      };
      final result = preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);
      expect(result.length, 4);
      expect(result.values.any((e) => e['sensor'] == '2'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '3'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '4'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '5'), isTrue);
    });

    test('handles surface sensors', () {
      final sensors = [
        Sensor()..id = '9'..title = 'Surface Asphalt',
        Sensor()..id = '10'..title = 'Surface Sett',
        Sensor()..id = '11'..title = 'Surface Compacted',
        Sensor()..id = '12'..title = 'Surface Paving',
        Sensor()..id = '13'..title = 'Standing',
        Sensor()..id = '14'..title = 'Surface Anomaly',
      ];
      final senseBox = SenseBox(sensors: sensors);
      final preparer = UploadDataPreparer(senseBox: senseBox);
      final gpsBuffer = [GeolocationData()
        ..latitude = 10.0
        ..longitude = 20.0
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0)];
      final groupedData = {
        gpsBuffer[0]: {
          'surface_classification': [10.0, 15.0, 20.0, 25.0, 30.0],
          'surface_anomaly': [35.0],
        },
      };
      final result = preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);
      expect(result.length, 6);
      expect(result.values.any((e) => e['sensor'] == '9'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '10'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '11'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '12'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '13'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '14'), isTrue);
    });

    test('handles overtaking sensor', () {
      final overtakingSensor = Sensor()..id = '6'..title = 'Overtaking Manoeuvre';
      final senseBox = SenseBox(sensors: [overtakingSensor]);
      final preparer = UploadDataPreparer(senseBox: senseBox);
      final gpsBuffer = [GeolocationData()
        ..latitude = 10.0
        ..longitude = 20.0
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0)];
      final groupedData = {
        gpsBuffer[0]: {
          'overtaking': [55.0],
        },
      };
      final result = preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);
      expect(result.length, 1);
      expect(result.values.first['sensor'], '6');
      expect(result.values.first['value'], '55.00');
    });
  });
}
