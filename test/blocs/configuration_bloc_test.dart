import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/services/remote_data_service.dart';
import 'package:sensebox_bike/constants.dart';
import '../sensor_catalog_test_data.dart';

class MockRemoteDataService extends Mock implements RemoteDataService {}

Future<dynamic> _loadTestBundledJson(String assetPath) async {
  final file = File(assetPath);
  return json.decode(await file.readAsString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigurationBloc', () {
    late MockRemoteDataService mockRemoteDataService;
    late ConfigurationBloc bloc;

    final mockBoxConfigurations = [
      {
        'id': 'classic',
        'displayName': '2022',
        'defaultGrouptag': 'classic',
        'sensors': [
          {'key': 'temperature'},
          {'key': 'humidity'},
        ],
      },
    ];

    setUp(() {
      mockRemoteDataService = MockRemoteDataService();
      bloc = ConfigurationBloc(
        remoteDataService: mockRemoteDataService,
        loadBundledJson: _loadTestBundledJson,
      );
      reset(mockRemoteDataService);
      when(() => mockRemoteDataService.fetchJson(sensorsUrl))
          .thenAnswer((_) async => mockSensorCatalogJson);
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

    group('loadSensorCatalog()', () {
      test('loads and parses sensor catalog successfully', () async {
        await bloc.loadSensorCatalog();

        expect(bloc.sensorCatalog, isNotNull);
        expect(bloc.sensorCatalog!.length, 3);
        expect(bloc.isLoadingSensorCatalog, false);
        expect(bloc.sensorCatalogError, isNull);
        verify(() => mockRemoteDataService.fetchJson(sensorsUrl)).called(1);
      });
    });

    group('loadBoxConfigurations()', () {
      final boxConfigs = [
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
          'sensors': [],
        },
      ];

      test('loads and parses box configurations successfully', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => boxConfigs);

        await bloc.loadBoxConfigurations();

        expect(bloc.boxConfigurations, isNotNull);
        expect(bloc.boxConfigurations!.length, 3);
        expect(bloc.boxConfigurations!.any((config) => config.id == 'classic'),
            true);
        expect(bloc.boxConfigurations!.any((config) => config.id == 'atrai'),
            true);
        expect(bloc.boxConfigurations!.any((config) => config.id == 'all'), true);
        expect(
          bloc.boxConfigurations!.last.sensors.length,
          bloc.sensorCatalog!.length,
        );
        expect(bloc.boxConfigurations!.first.sensors.first.title, 'Temperature');
        expect(bloc.isLoadingBoxConfigurations, false);
        expect(bloc.boxConfigurationsError, isNull);
        verify(() => mockRemoteDataService.fetchJson(sensorsUrl)).called(1);
        verify(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .called(1);
      });

      test('sets loading state during load', () async {
        await bloc.loadSensorCatalog();

        final completer = Completer<List<dynamic>>();
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) => completer.future);

        final loadFuture = bloc.loadBoxConfigurations();
        expect(bloc.isLoadingBoxConfigurations, true);

        completer.complete(boxConfigs);
        await loadFuture;

        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('falls back to bundled box configurations when remote fails', () async {
        when(() => mockRemoteDataService.fetchJson(sensorsUrl))
            .thenThrow(Exception('Network error'));
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenThrow(Exception('Network error'));

        await bloc.loadBoxConfigurations();

        expect(bloc.boxConfigurations, isNotNull);
        expect(bloc.boxConfigurationsError, isNull);
        expect(bloc.boxConfigurations!.any((config) => config.id == 'lauds_26'),
            true);
        expect(bloc.boxConfigurations!.any((config) => config.id == 'atrai'),
            true);
        expect(bloc.boxConfigurations!.any((config) => config.id == 'classic'),
            true);
        expect(bloc.boxConfigurations!.any((config) => config.id == 'all'), true);
        expect(
          bloc.boxConfigurations!.last.sensors.length,
          bloc.sensorCatalog!.length,
        );
        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('falls back to bundled data when remote format is invalid', () async {
        when(() => mockRemoteDataService.fetchJson(sensorsUrl))
            .thenAnswer((_) async => {'invalid': 'format'});
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => {'invalid': 'format'});

        await bloc.loadBoxConfigurations();

        expect(bloc.boxConfigurations, isNotNull);
        expect(bloc.boxConfigurationsError, isNull);
        expect(bloc.boxConfigurations!.length, 4);
        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('reloads when allowReload is true', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => boxConfigs);

        await bloc.loadBoxConfigurations();
        final firstLoadId = bloc.boxConfigurations?.first.id;

        await bloc.loadBoxConfigurations();
        final secondLoadId = bloc.boxConfigurations?.first.id;

        expect(firstLoadId, isNotNull);
        expect(secondLoadId, equals(firstLoadId));
        verify(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .called(2);
      });
    });

    group('loadAll()', () {
      final mockCampaigns = [
        {'label': 'Wiesbaden', 'value': 'wiesbaden'},
      ];

      test('loads catalog, box configurations, and campaigns', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);
        when(() => mockRemoteDataService.fetchJson(campaignsUrl))
            .thenAnswer((_) async => mockCampaigns);

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
      test('returns null when configurations not loaded', () {
        expect(bloc.getBoxConfigurationById('classic'), isNull);
      });

      test('returns configuration when found', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);

        await bloc.loadBoxConfigurations();

        final config = bloc.getBoxConfigurationById('classic');
        expect(config, isNotNull);
        expect(config!.id, 'classic');
        expect(config.displayName, '2022');
      });

      test('returns null when configuration not found', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);

        await bloc.loadBoxConfigurations();

        expect(bloc.getBoxConfigurationById('unknown_nonexistent_id'), isNull);
      });
    });
  });
}
