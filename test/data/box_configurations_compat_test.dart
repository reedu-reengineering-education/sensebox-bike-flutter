import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/box_configuration.dart';

import '../helpers/box_configurations_test_support.dart';
import '../sensor_catalog_test_data.dart';

/// Dual-file contract for box configs:
/// - [legacyBoxConfigurationsPath] keeps the inline shape for older installs
/// - [v2BoxConfigurationsPath] is the catalog-keyed shape for the current parser
///
/// Manual smoke after merge to main (not automated here):
/// - Older / store APK: remote `.../data/box_configurations.json` → models load
/// - This branch build: remote or bundled `box_configurations_v2.json` → models load
/// - New build offline: bundled v2 asset fallback → same models
void main() {
  group('box configuration dual-file contract', () {
    test('legacy file keeps inline shape for older app installs', () {
      final ids = <String>{};

      for (final item in loadJsonListFromFile(legacyBoxConfigurationsPath)) {
        final config = asJsonObject(item, legacyBoxConfigurationsPath);
        expectBoxConfigHeader(config, legacyBoxConfigurationsPath);
        ids.add(config['id'] as String);

        final sensors = config['sensors'] as List<dynamic>;
        for (var i = 0; i < sensors.length; i++) {
          final context = '${config['id']}[$i]';
          final sensor = asJsonObject(sensors[i], context);

          for (final field in legacyInlineSensorFields) {
            expectNonEmptyString(
              sensor[field],
              reason: '$context missing inline "$field"',
            );
          }
          expect(
            sensor.containsKey('key'),
            isFalse,
            reason: '$context must not use catalog "key"',
          );
        }
      }

      expectContainsModelIds(ids);
    });

    test('v2 file uses catalog-keyed shape for current app', () {
      final ids = <String>{};

      for (final item in loadJsonListFromFile(v2BoxConfigurationsPath)) {
        final config = asJsonObject(item, v2BoxConfigurationsPath);
        expectBoxConfigHeader(config, v2BoxConfigurationsPath);
        ids.add(config['id'] as String);

        final sensors = config['sensors'] as List<dynamic>;
        for (var i = 0; i < sensors.length; i++) {
          final context = '${config['id']}[$i]';
          final sensor = asJsonObject(sensors[i], context);

          expectNonEmptyString(
            sensor['key'],
            reason: '$context missing catalog "key"',
          );
          for (final field in sensor.keys) {
            expect(
              catalogRefSensorFields.contains(field),
              isTrue,
              reason: '$context unexpected field "$field"',
            );
          }
        }
      }

      expectContainsModelIds(ids);
    });
  });

  group('current app parser vs dual files', () {
    setUp(setupSensorCatalogFromRepo);
    tearDown(clearMockSensorCatalog);

    test('parses every v2 box configuration with real sensors.json', () {
      final parsed = <String, BoxConfiguration>{};
      for (final item in loadJsonListFromFile(v2BoxConfigurationsPath)) {
        final config = BoxConfiguration.fromJson(
          asJsonObject(item, v2BoxConfigurationsPath),
        );
        parsed[config.id] = config;
      }

      expectContainsModelIds(parsed.keys);

      final lauds = requireProfile(parsed.values, 'lauds_26');
      expect(lauds.sensors.first.title, 'Distance Left');
      expect(lauds.sensors.first.key, 'distance');

      final atrai = requireProfile(parsed.values, 'atrai');
      expect(atrai.sensors.first.title, 'Overtaking Distance');
      expect(atrai.sensors.first.key, 'distance');

      final classic = requireProfile(parsed.values, 'classic');
      expect(classic.sensors.any((s) => s.key == 'temperature'), isTrue);
    });

    test('rejects legacy inline box configurations', () {
      final first = asJsonObject(
        loadJsonListFromFile(legacyBoxConfigurationsPath).first,
        legacyBoxConfigurationsPath,
      );

      expect(
        () => BoxConfiguration.fromJson(first),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('missing required field "key"'),
          ),
        ),
      );
    });
  });
}
