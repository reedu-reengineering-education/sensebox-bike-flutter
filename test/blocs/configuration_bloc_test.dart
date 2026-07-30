import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/services/remote_data_service.dart';

import '../helpers/box_configurations_test_support.dart';
import '../sensor_catalog_test_data.dart';

class MockRemoteDataService extends Mock implements RemoteDataService {}

Future<dynamic> _loadTestBundledJson(String assetPath) async {
  return json.decode(await File(assetPath).readAsString());
}

final _classicBoxConfig = {
  'id': 'classic',
  'displayName': '2022',
  'defaultGrouptag': 'classic',
  'sensors': [
    {'key': 'temperature'},
    {'key': 'humidity'},
  ],
};

final _remoteBoxConfigs = [
  {
    'id': 'classic',
    'displayName': '2022',
    'defaultGrouptag': 'classic',
    'sensors': [
      {'key': 'temperature'},
    ],
  },
  {
    'id': 'atrai',
    'displayName': '2025',
    'defaultGrouptag': 'atrai',
    'sensors': <Map<String, dynamic>>[],
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigurationBloc', () {
    late MockRemoteDataService remote;
    late ConfigurationBloc bloc;

    void stubSensors([Object? response]) {
      if (response is Exception) {
        when(() => remote.fetchJson(sensorsUrl)).thenThrow(response);
      } else {
        when(() => remote.fetchJson(sensorsUrl)).thenAnswer(
          (_) async => response ?? mockSensorCatalogJson,
        );
      }
    }

    void stubBoxConfigs(Object response) {
      if (response is Exception) {
        when(() => remote.fetchJson(boxConfigurationsUrl)).thenThrow(response);
      } else {
        when(() => remote.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => response);
      }
    }

    void expectBundledProfilesLoaded({String? laudsFirstTitle}) {
      expect(bloc.boxConfigurations, isNotNull);
      expect(bloc.boxConfigurationsError, isNull);
      expectHasBoxProfileIds(bloc.boxConfigurations!);
      if (laudsFirstTitle != null) {
        expect(
          requireProfile(bloc.boxConfigurations!, 'lauds_26').sensors.first.title,
          laudsFirstTitle,
        );
      }
    }

    setUp(() {
      remote = MockRemoteDataService();
      bloc = ConfigurationBloc(
        remoteDataService: remote,
        loadBundledJson: _loadTestBundledJson,
      );
      reset(remote);
      stubSensors();
    });

    tearDown(clearMockSensorCatalog);

    test('initial state has null configurations and campaigns', () {
      expect(bloc.boxConfigurations, isNull);
      expect(bloc.sensorCatalog, isNull);
      expect(bloc.campaigns, isNull);
      expect(bloc.isLoadingBoxConfigurations, false);
      expect(bloc.isLoadingCampaigns, false);
      expect(bloc.boxConfigurationsError, isNull);
      expect(bloc.campaignsError, isNull);
    });

    test('points remote and asset paths at catalog-keyed v2 configs', () {
      expect(boxConfigurationsPath, '/box_configurations_v2.json');
      expect(boxConfigurationsAssetPath, v2BoxConfigurationsPath);
      expect(boxConfigurationsUrl, endsWith('/box_configurations_v2.json'));
    });

    group('loadSensorCatalog()', () {
      test('loads and parses sensor catalog successfully', () async {
        await bloc.loadSensorCatalog();

        expect(bloc.sensorCatalog, isNotNull);
        expect(bloc.sensorCatalog!.length, mockSensorCatalogJson.length);
        expect(bloc.isLoadingSensorCatalog, false);
        expect(bloc.sensorCatalogError, isNull);
        verify(() => remote.fetchJson(sensorsUrl)).called(1);
      });
    });

    group('loadBoxConfigurations()', () {
      test('loads and parses box configurations successfully', () async {
        stubBoxConfigs(_remoteBoxConfigs);

        await bloc.loadBoxConfigurations();

        expect(bloc.boxConfigurations, isNotNull);
        expect(bloc.boxConfigurations!.length, 3);
        expect(
          bloc.boxConfigurations!.map((c) => c.id),
          containsAll(['classic', 'atrai', 'all']),
        );
        expect(
          bloc.boxConfigurations!.last.sensors.length,
          bloc.sensorCatalog!.length,
        );
        expect(
          bloc.boxConfigurations!.last.dataCollectionMode,
          DataCollectionMode.gpsDriven,
        );
        expect(bloc.boxConfigurations!.first.sensors.first.title, 'Temperature');
        expect(bloc.isLoadingBoxConfigurations, false);
        expect(bloc.boxConfigurationsError, isNull);
        verify(() => remote.fetchJson(sensorsUrl)).called(1);
        verify(() => remote.fetchJson(boxConfigurationsUrl)).called(1);
      });

      test('sets loading state during load', () async {
        await bloc.loadSensorCatalog();

        final completer = Completer<List<dynamic>>();
        when(() => remote.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) => completer.future);

        final loadFuture = bloc.loadBoxConfigurations();
        expect(bloc.isLoadingBoxConfigurations, true);

        completer.complete(_remoteBoxConfigs);
        await loadFuture;

        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('falls back to bundled box configurations when remote fails',
          () async {
        stubSensors(Exception('Network error'));
        stubBoxConfigs(Exception('Network error'));

        await bloc.loadBoxConfigurations();

        expectBundledProfilesLoaded();
        expect(
          bloc.boxConfigurations!.last.sensors.length,
          bloc.sensorCatalog!.length,
        );
        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('falls back to bundled data when remote format is invalid', () async {
        stubSensors({'invalid': 'format'});
        stubBoxConfigs({'invalid': 'format'});

        await bloc.loadBoxConfigurations();

        expectBundledProfilesLoaded();
        expect(bloc.boxConfigurations!.length, 4);
        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('falls back to bundled v2 when remote returns legacy inline format',
          () async {
        final legacyConfigs =
            loadJsonListFromFile(legacyBoxConfigurationsPath);

        // Force full bundled sensors.json so v2 catalog refs can resolve.
        stubSensors(Exception('Network error'));
        stubBoxConfigs(legacyConfigs);

        await bloc.loadBoxConfigurations();

        expectBundledProfilesLoaded(laudsFirstTitle: 'Distance Left');
      });

      test('reloads when allowReload is true', () async {
        stubBoxConfigs(_remoteBoxConfigs);

        await bloc.loadBoxConfigurations();
        final firstLoadId = bloc.boxConfigurations?.first.id;

        await bloc.loadBoxConfigurations();
        final secondLoadId = bloc.boxConfigurations?.first.id;

        expect(firstLoadId, isNotNull);
        expect(secondLoadId, firstLoadId);
        verify(() => remote.fetchJson(boxConfigurationsUrl)).called(2);
      });
    });

    group('loadAll()', () {
      test('loads catalog, box configurations, and campaigns', () async {
        stubBoxConfigs([_classicBoxConfig]);
        when(() => remote.fetchJson(campaignsUrl)).thenAnswer(
          (_) async => [
            {'label': 'Wiesbaden', 'value': 'wiesbaden'},
          ],
        );

        await bloc.loadAll();

        expect(bloc.sensorCatalog, isNotNull);
        expect(bloc.boxConfigurations, isNotNull);
        expect(bloc.boxConfigurations!.length, 2);
        expect(bloc.boxConfigurations!.first.id, 'classic');
        expect(bloc.boxConfigurations!.last.id, 'all');
        expect(bloc.boxConfigurations!.first.displayName, '2022');
        expect(bloc.boxConfigurations!.first.defaultGrouptag, 'classic');

        expect(bloc.campaigns, isNotNull);
        expect(bloc.campaigns!.length, 1);
        expect(bloc.campaigns!.first.label, 'Wiesbaden');
        expect(bloc.campaigns!.first.value, 'wiesbaden');
      });
    });

    group('getBoxConfigurationById()', () {
      Future<void> loadClassicConfig() async {
        stubBoxConfigs([_classicBoxConfig]);
        await bloc.loadBoxConfigurations();
      }

      test('returns null when configurations not loaded', () {
        expect(bloc.getBoxConfigurationById('classic'), isNull);
      });

      test('returns configuration when found', () async {
        await loadClassicConfig();

        final config = bloc.getBoxConfigurationById('classic');
        expect(config, isNotNull);
        expect(config!.id, 'classic');
        expect(config.displayName, '2022');
      });

      test('returns null when configuration not found', () async {
        await loadClassicConfig();

        expect(bloc.getBoxConfigurationById('unknown_nonexistent_id'), isNull);
      });
    });
  });
}
