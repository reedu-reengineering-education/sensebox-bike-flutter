import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/box_configuration.dart';

/// Legacy inline format kept for older app installs.
const legacyBoxConfigurationsPath = 'data/box_configurations.json';

/// Catalog-keyed format required by the current app parser.
const v2BoxConfigurationsPath = 'data/box_configurations_v2.json';

const expectedBoxModelIds = {'atrai', 'lauds_26', 'classic'};

const legacyInlineSensorFields = {
  'id',
  'icon',
  'title',
  'unit',
  'sensorType',
};

const catalogRefSensorFields = {'key', 'attribute', 'title', 'id'};

List<dynamic> loadJsonListFromFile(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist');
  final decoded = jsonDecode(file.readAsStringSync());
  expect(decoded, isA<List>(), reason: '$path must be a JSON list');
  final list = decoded as List<dynamic>;
  expect(list, isNotEmpty, reason: '$path must not be empty');
  return list;
}

Map<String, dynamic> asJsonObject(dynamic value, String context) {
  expect(value, isA<Map>(), reason: '$context must be an object');
  return Map<String, dynamic>.from(value as Map);
}

void expectNonEmptyString(
  dynamic value, {
  required String reason,
}) {
  expect(value, isA<String>(), reason: reason);
  expect((value as String).isNotEmpty, isTrue, reason: reason);
}

/// Shared top-level fields for both legacy and v2 box config objects.
void expectBoxConfigHeader(Map<String, dynamic> config, String context) {
  expectNonEmptyString(config['id'], reason: '$context missing id');
  expectNonEmptyString(
    config['displayName'],
    reason: '$context missing displayName',
  );
  expectNonEmptyString(
    config['defaultGrouptag'],
    reason: '$context missing defaultGrouptag',
  );
  expect(config['sensors'], isA<List>(), reason: '$context missing sensors');
  expect(
    (config['sensors'] as List).isNotEmpty,
    isTrue,
    reason: '$context needs sensors',
  );
}

void expectContainsModelIds(Iterable<String> ids) {
  expect(ids.toSet(), containsAll(expectedBoxModelIds));
}

void expectHasBoxProfileIds(
  Iterable<BoxConfiguration> configs, {
  bool includeAll = true,
}) {
  final ids = configs.map((c) => c.id).toSet();
  expectContainsModelIds(ids);
  if (includeAll) {
    expect(ids, contains('all'));
  }
}

BoxConfiguration requireProfile(
  Iterable<BoxConfiguration> configs,
  String id,
) {
  return configs.firstWhere((c) => c.id == id);
}
