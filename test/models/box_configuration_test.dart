import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/box_configuration.dart';

void main() {
  group('BoxConfiguration.fromJson', () {
    test('parses valid JSON successfully', () {
      final json = {
        'id': 'classic',
        'displayName': '2022',
        'defaultGrouptag': 'classic',
        'sensors': [
          {
            'id': '0',
            'icon': 'osem-thermometer',
            'title': 'Temperature',
            'unit': '°C',
            'sensorType': 'HDC1080',
          }
        ],
      };
      final config = BoxConfiguration.fromJson(json);
      expect(config.id, 'classic');
      expect(config.displayName, '2022');
      expect(config.defaultGrouptag, 'classic');
      expect(config.sensors.length, 1);
      expect(config.sensors.first.title, 'Temperature');
    });

    test('throws FormatException when id is missing', () {
      final json = {
        'displayName': '2022',
        'defaultGrouptag': 'classic',
        'sensors': [],
      };
      expect(
        () => BoxConfiguration.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing required field "id"'),
        )),
      );
    });

    test('throws FormatException when sensors is missing', () {
      final json = {
        'id': 'classic',
        'displayName': '2022',
        'defaultGrouptag': 'classic',
      };
      expect(
        () => BoxConfiguration.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing required field "sensors"'),
        )),
      );
    });

    test('throws FormatException when sensors has wrong type', () {
      final json = {
        'id': 'classic',
        'displayName': '2022',
        'defaultGrouptag': 'classic',
        'sensors': 'not a list',
      };
      expect(
        () => BoxConfiguration.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('must be a List'),
        )),
      );
    });
  });

  group('SensorDefinition.fromJson', () {
    test('parses valid JSON successfully', () {
      final json = {
        'id': '0',
        'icon': 'osem-thermometer',
        'title': 'Temperature',
        'unit': '°C',
        'sensorType': 'HDC1080',
      };
      final sensor = SensorDefinition.fromJson(json);
      expect(sensor.id, '0');
      expect(sensor.icon, 'osem-thermometer');
      expect(sensor.title, 'Temperature');
      expect(sensor.unit, '°C');
      expect(sensor.sensorType, 'HDC1080');
    });

    test('throws FormatException when title is missing', () {
      final json = {
        'id': '0',
        'icon': 'osem-thermometer',
        'unit': '°C',
        'sensorType': 'HDC1080',
      };
      expect(
        () => SensorDefinition.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing required field "title"'),
        )),
      );
    });

    test('throws FormatException when title has wrong type', () {
      final json = {
        'id': '0',
        'icon': 'osem-thermometer',
        'title': 123,
        'unit': '°C',
        'sensorType': 'HDC1080',
      };
      expect(
        () => SensorDefinition.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('must be a String'),
        )),
      );
    });
  });
}

