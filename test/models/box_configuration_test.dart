import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import '../sensor_catalog_test_data.dart';

void main() {
  setUp(setupMockSensorCatalog);
  tearDown(clearMockSensorCatalog);

  group('BoxConfiguration.fromJson', () {
    test('parses valid JSON successfully', () {
      final json = {
        'id': 'classic',
        'displayName': '2022',
        'defaultGrouptag': 'classic',
        'sensors': [
          {'key': 'temperature'},
        ],
      };
      final config = BoxConfiguration.fromJson(json);
      expect(config.id, 'classic');
      expect(config.displayName, '2022');
      expect(config.defaultGrouptag, 'classic');
      expect(config.sensors.length, 1);
      expect(config.sensors.first.title, 'Temperature');
      expect(config.sensors.first.key, 'temperature');
    });

    test('resolves title override from box config', () {
      final json = {
        'id': 'classic',
        'displayName': '2022',
        'defaultGrouptag': 'classic',
        'sensors': [
          {'key': 'distance', 'title': 'Overtaking Distance'},
        ],
      };
      final config = BoxConfiguration.fromJson(json);
      expect(config.sensors.first.title, 'Overtaking Distance');
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

    test('round-trips through toJson', () {
      final json = {
        'id': 'classic',
        'displayName': '2022',
        'defaultGrouptag': 'classic',
        'sensors': [
          {'key': 'temperature'},
          {'key': 'humidity'},
        ],
      };
      final config = BoxConfiguration.fromJson(json);
      expect(config.toJson(), json);
    });
  });

  group('SensorDefinition.fromJsonRef', () {
    test('parses valid key ref successfully', () {
      final sensor = SensorDefinition.fromJsonRef(
        {'key': 'temperature'},
        fallbackId: '0',
      );
      expect(sensor.id, '0');
      expect(sensor.icon, 'osem-thermometer');
      expect(sensor.title, 'Temperature');
      expect(sensor.unit, '°C');
      expect(sensor.sensorType, 'HDC1080');
    });

    test('throws FormatException when key is missing', () {
      expect(
        () => SensorDefinition.fromJsonRef({}, fallbackId: '0'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing required field "key"'),
        )),
      );
    });

    test('throws FormatException when catalog entry is missing', () {
      expect(
        () => SensorDefinition.fromJsonRef(
          {'key': 'unknown_sensor'},
          fallbackId: '0',
        ),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('no catalog entry'),
        )),
      );
    });
  });
}
