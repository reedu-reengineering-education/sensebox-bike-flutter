import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/remote_data_service.dart';
import 'package:sensebox_bike/constants.dart';

class MockRemoteDataService extends Mock implements RemoteDataService {}

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
          {
            'id': '0',
            'icon': 'osem-thermometer',
            'title': 'Temperature',
            'unit': '°C',
            'sensorType': 'HDC1080',
          },
          {
            'id': '1',
            'icon': 'osem-humidity',
            'title': 'Humidity',
            'unit': '%',
            'sensorType': 'HDC1080',
          },
        ],
      },
    ];

    setUp(() {
      mockRemoteDataService = MockRemoteDataService();
      bloc = ConfigurationBloc(remoteDataService: mockRemoteDataService);
    });

    test('initial state has null configurations and campaigns', () {
      expect(bloc.boxConfigurations, isNull);
      expect(bloc.campaigns, isNull);
      expect(bloc.isLoadingBoxConfigurations, false);
      expect(bloc.isLoadingCampaigns, false);
      expect(bloc.boxConfigurationsError, isNull);
      expect(bloc.campaignsError, isNull);
    });

    group('loadBoxConfigurations()', () {
      final mockBoxConfigurations = [
        {
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
              'characteristicUuid': '2cdf2174-35be-fdc4-4ca2-6fd173f8b3a8',
            }
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
            .thenAnswer((_) async => mockBoxConfigurations);

        await bloc.loadBoxConfigurations();

        expect(bloc.boxConfigurations, isNotNull);
        expect(bloc.boxConfigurations!.length, 1);
        expect(bloc.boxConfigurations!.first.id, 'classic');
        expect(bloc.isLoadingBoxConfigurations, false);
        expect(bloc.boxConfigurationsError, isNull);
      });

      test('sets loading state during load', () async {
        final completer = Completer<List<dynamic>>();
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) => completer.future);

        final loadFuture = bloc.loadBoxConfigurations();
        expect(bloc.isLoadingBoxConfigurations, true);
        
        completer.complete(mockBoxConfigurations);
        await loadFuture;
        
        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('handles fetch error', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenThrow(Exception('Network error'));

        await bloc.loadBoxConfigurations();

        expect(bloc.boxConfigurations, isNull);
        expect(bloc.boxConfigurationsError, isNotNull);
        expect(bloc.boxConfigurationsError,
            contains('Failed to load box configurations'));
        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('handles invalid data format', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => {'invalid': 'format'});

        await bloc.loadBoxConfigurations();

        expect(bloc.boxConfigurations, isNull);
        expect(bloc.boxConfigurationsError, isNotNull);
        expect(bloc.boxConfigurationsError,
            contains('Invalid box configurations format'));
        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('reloads when allowReload is true', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);

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

      test('loads both box configurations and campaigns', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);
        when(() => mockRemoteDataService.fetchJson(campaignsUrl))
            .thenAnswer((_) async => mockCampaigns);

        await bloc.loadAll();

        expect(bloc.boxConfigurations, isNotNull);
        expect(bloc.boxConfigurations!.length, 1);
        expect(bloc.boxConfigurations!.first.id, 'classic');
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

    group('isSenseBoxBikeCompatible()', () {
      test('returns false when configurations not loaded', () {
        final senseBox = SenseBox(
          sensors: [
            Sensor(title: 'Temperature', unit: '°C', sensorType: 'HDC1080'),
          ],
        );

        expect(bloc.isSenseBoxBikeCompatible(senseBox), false);
      });

      test('returns false when senseBox has no sensors', () async {
        final mockBoxConfigurations = [
          {
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
                'characteristicUuid': '2cdf2174-35be-fdc4-4ca2-6fd173f8b3a8',
              },
            ],
          },
        ];

        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);

        await bloc.loadBoxConfigurations();

        final senseBox = SenseBox(sensors: []);
        expect(bloc.isSenseBoxBikeCompatible(senseBox), false);
      });

      test('returns true when all sensors are compatible', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);

        await bloc.loadBoxConfigurations();

        final senseBox = SenseBox(
          sensors: [
            Sensor(title: 'Temperature', unit: '°C', sensorType: 'HDC1080'),
            Sensor(title: 'Humidity', unit: '%', sensorType: 'HDC1080'),
          ],
        );

        expect(bloc.isSenseBoxBikeCompatible(senseBox), true);
      });

      test('returns false when some sensors are not compatible', () async {
        final mockBoxConfigurations = [
          {
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
                'characteristicUuid': '2cdf2174-35be-fdc4-4ca2-6fd173f8b3a8',
              },
            ],
          },
        ];

        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);

        await bloc.loadBoxConfigurations();

        final senseBox = SenseBox(
          sensors: [
            Sensor(title: 'Temperature', unit: '°C', sensorType: 'HDC1080'),
            Sensor(
                title: 'Unknown Sensor That Does Not Exist',
                unit: '?',
                sensorType: 'UNKNOWN'),
          ],
        );

        expect(bloc.isSenseBoxBikeCompatible(senseBox), false);
      });
    });

  });
}

