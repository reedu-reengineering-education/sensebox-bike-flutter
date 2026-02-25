import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/utils/track_utils.dart';

void main() {
  group('UploadDataPreparer Classic', () {
    test('handles acceleration sensors', () {
      final sensors = [
        Sensor()..id = '7'..title = 'Acceleration X',
        Sensor()..id = '8'..title = 'Acceleration Y',
        Sensor()..id = '9'..title = 'Acceleration Z',
      ];
      final senseBox = SenseBox(sensors: sensors);
      final preparer = UploadDataPreparer(senseBox: senseBox);
      final gpsBuffer = [GeolocationData()
        ..latitude = 10.0
        ..longitude = 20.0
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0)];
      final groupedData = {
        gpsBuffer[0]: {
          'acceleration': [0.1, 0.2, 0.3],
        },
      };
      final result = preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);
      expect(result.length, 3);
      expect(result.values.any((e) => e['sensor'] == '7'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '8'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '9'), isTrue);
    });

    test('handles temperature, humidity, speed', () {
      final sensors = [
        Sensor()..id = '0'..title = 'Temperature',
        Sensor()..id = '1'..title = 'Rel. Humidity',
        Sensor()..id = '10'..title = 'Speed',
      ];
      final senseBox = SenseBox(sensors: sensors);
      final preparer = UploadDataPreparer(senseBox: senseBox);
      final gpsBuffer = [GeolocationData()
        ..latitude = 10.0
        ..longitude = 20.0
        ..speed = 7.5
        ..timestamp = DateTime.utc(2024, 1, 1, 12, 0, 0)];
      final groupedData = {
        gpsBuffer[0]: {
          'temperature': [21.5],
          'humidity': [45.0],
        },
      };
      final result = preparer.prepareDataFromGroupedData(groupedData, gpsBuffer);
      expect(result.length, 3);
      expect(result.values.any((e) => e['sensor'] == '0'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '1'), isTrue);
      expect(result.values.any((e) => e['sensor'] == '10'), isTrue);
    });
  });
}
