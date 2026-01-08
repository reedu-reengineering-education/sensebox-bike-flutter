import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/services/remote_data_service.dart';
import 'package:sensebox_bike/constants.dart';

class MockRemoteDataService extends Mock implements RemoteDataService {}

void main() {
  group('ConfigurationBloc', () {
    late MockRemoteDataService mockRemoteDataService;
    late ConfigurationBloc bloc;

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
        expect(bloc.boxConfigurations!.length, 2);
        expect(bloc.boxConfigurations!.first.id, 'classic');
        expect(bloc.boxConfigurations!.first.displayName, '2022');
        expect(bloc.isLoadingBoxConfigurations, false);
        expect(bloc.boxConfigurationsError, isNull);
      });

      test('sets loading state during load', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => mockBoxConfigurations,
                ));

        final loadFuture = bloc.loadBoxConfigurations();
        expect(bloc.isLoadingBoxConfigurations, true);
        await loadFuture;
        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('handles network error', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenThrow(Exception('Network error'));

        await bloc.loadBoxConfigurations();

        expect(bloc.boxConfigurations, isNull);
        expect(bloc.boxConfigurationsError, contains('Failed to load box configurations'));
        expect(bloc.isLoadingBoxConfigurations, false);
      });

      test('handles invalid data format', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => {'invalid': 'format'});

        await bloc.loadBoxConfigurations();

        expect(bloc.boxConfigurations, isNull);
        expect(bloc.boxConfigurationsError, contains('Failed to load box configurations'));
      });

      test('does not reload if already loaded', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);

        await bloc.loadBoxConfigurations();
        await bloc.loadBoxConfigurations();

        verify(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl)).called(1);
      });

      test('does not reload if already loading', () async {
        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => mockBoxConfigurations,
                ));

        final load1 = bloc.loadBoxConfigurations();
        final load2 = bloc.loadBoxConfigurations();
        await Future.wait([load1, load2]);

        verify(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl)).called(1);
      });
    });

    group('loadCampaigns()', () {
      final mockCampaigns = [
        {'label': 'Wiesbaden', 'value': 'wiesbaden'},
        {'label': 'Münster', 'value': 'muenster'},
      ];

      test('loads and parses campaigns successfully', () async {
        when(() => mockRemoteDataService.fetchJson(campaignsUrl))
            .thenAnswer((_) async => mockCampaigns);

        await bloc.loadCampaigns();

        expect(bloc.campaigns, isNotNull);
        expect(bloc.campaigns!.length, 2);
        expect(bloc.campaigns!.first.label, 'Wiesbaden');
        expect(bloc.campaigns!.first.value, 'wiesbaden');
        expect(bloc.isLoadingCampaigns, false);
        expect(bloc.campaignsError, isNull);
      });

      test('sets loading state during load', () async {
        when(() => mockRemoteDataService.fetchJson(campaignsUrl))
            .thenAnswer((_) async => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => mockCampaigns,
                ));

        final loadFuture = bloc.loadCampaigns();
        expect(bloc.isLoadingCampaigns, true);
        await loadFuture;
        expect(bloc.isLoadingCampaigns, false);
      });

      test('handles network error', () async {
        when(() => mockRemoteDataService.fetchJson(campaignsUrl))
            .thenThrow(Exception('Network error'));

        await bloc.loadCampaigns();

        expect(bloc.campaigns, isNull);
        expect(bloc.campaignsError, contains('Failed to load campaigns'));
        expect(bloc.isLoadingCampaigns, false);
      });

      test('handles invalid data format', () async {
        when(() => mockRemoteDataService.fetchJson(campaignsUrl))
            .thenAnswer((_) async => {'invalid': 'format'});

        await bloc.loadCampaigns();

        expect(bloc.campaigns, isNull);
        expect(bloc.campaignsError, contains('Failed to load campaigns'));
      });

      test('does not reload if already loaded', () async {
        when(() => mockRemoteDataService.fetchJson(campaignsUrl))
            .thenAnswer((_) async => mockCampaigns);

        await bloc.loadCampaigns();
        await bloc.loadCampaigns();

        verify(() => mockRemoteDataService.fetchJson(campaignsUrl)).called(1);
      });
    });

    group('loadAll()', () {
      final mockBoxConfigurations = [
        {
          'id': 'classic',
          'displayName': '2022',
          'defaultGrouptag': 'classic',
          'sensors': [],
        },
      ];
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
        expect(bloc.campaigns, isNotNull);
      });
    });

    group('getBoxConfigurationById()', () {
      test('returns null when configurations not loaded', () {
        expect(bloc.getBoxConfigurationById('classic'), isNull);
      });

      test('returns configuration when found', () async {
        final mockBoxConfigurations = [
          {
            'id': 'classic',
            'displayName': '2022',
            'defaultGrouptag': 'classic',
            'sensors': [],
          },
          {
            'id': 'atrai',
            'displayName': '2025',
            'defaultGrouptag': 'atrai',
            'sensors': [],
          },
        ];

        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);

        await bloc.loadBoxConfigurations();

        final config = bloc.getBoxConfigurationById('atrai');
        expect(config, isNotNull);
        expect(config!.id, 'atrai');
        expect(config.displayName, '2025');
      });

      test('returns null when configuration not found', () async {
        final mockBoxConfigurations = [
          {
            'id': 'classic',
            'displayName': '2022',
            'defaultGrouptag': 'classic',
            'sensors': [],
          },
        ];

        when(() => mockRemoteDataService.fetchJson(boxConfigurationsUrl))
            .thenAnswer((_) async => mockBoxConfigurations);

        await bloc.loadBoxConfigurations();

        expect(bloc.getBoxConfigurationById('unknown'), isNull);
      });
    });
  });
}

