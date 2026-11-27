import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/sensor_catalog_entry.dart';
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

  group('BoxConfiguration.custom', () {
    final catalog =
        (jsonDecode(File('data/sensors.json').readAsStringSync()) as List)
            .map((e) => SensorCatalogEntry.fromJson(e as Map<String, dynamic>))
            .toList();

    test('selectableSensorKeys lists each key once in catalog order', () {
      expect(BoxConfiguration.selectableSensorKeys(catalog), [
        'temperature',
        'humidity',
        'finedust',
        'distance',
        'distance_right',
        'overtaking',
        'surface_classification',
        'surface_anomaly',
        'acceleration',
        'gps',
      ]);
    });

    test('includes all attributes of a selected multi-value sensor', () {
      final config = BoxConfiguration.custom(
        catalog: catalog,
        sensorKeys: {'temperature', 'finedust'},
      );

      expect(config.id, BoxConfiguration.customId);
      expect(config.defaultGrouptag, BoxConfiguration.customId);
      expect(config.sensors.map((s) => s.title), [
        'Temperature',
        'Finedust PM1',
        'Finedust PM2.5',
        'Finedust PM4',
        'Finedust PM10',
      ]);
      expect(config.sensors.map((s) => s.id), ['0', '1', '2', '3', '4']);
    });

    test('adds a single "Distance Left" sensor for the distance key', () {
      final config = BoxConfiguration.custom(
        catalog: catalog,
        sensorKeys: {'distance', 'distance_right'},
      );

      expect(config.sensors.map((s) => s.title),
          ['Distance Left', 'Distance Right']);
    });

    test('ignores unknown keys and keeps catalog order', () {
      final config = BoxConfiguration.custom(
        catalog: catalog,
        sensorKeys: {'gps', 'humidity', 'does_not_exist'},
      );

      expect(config.sensors.map((s) => s.title), ['Rel. Humidity', 'Speed']);
      expect(config.sensorsAsMap.first.keys,
          containsAll(['id', 'icon', 'title', 'unit', 'sensorType']));
    });
  });

  group('BoxConfiguration featured flag', () {
    Map<String, dynamic> json({Object? featured}) => {
          'id': 'atrai',
          'displayName': 'senseBox:bike',
          'defaultGrouptag': 'atrai',
          if (featured != null) 'featured': featured,
          'sensors': [
            {'key': 'temperature'},
          ],
        };

    test('defaults to false when missing', () {
      expect(BoxConfiguration.fromJson(json()).featured, isFalse);
    });

    test('parses true and round-trips through toJson', () {
      final config = BoxConfiguration.fromJson(json(featured: true));
      expect(config.featured, isTrue);
      expect(config.toJson()['featured'], isTrue);
      expect(BoxConfiguration.fromJson(json()).toJson(),
          isNot(contains('featured')));
    });

    test('bundled config features the senseBox:bike model', () {
      final configs = (jsonDecode(
                  File('data/box_configurations_v2.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
      final featured = configs.where((c) => c['featured'] == true).toList();
      expect(featured.map((c) => c['id']), ['atrai']);
      expect(featured.single['displayName'], 'senseBox:bike');
    });
  });
}
