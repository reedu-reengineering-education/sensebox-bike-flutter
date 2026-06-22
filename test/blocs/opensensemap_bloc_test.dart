import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:mocktail/mocktail.dart';
import '../sensor_catalog_test_data.dart';

class MockConfigurationBloc extends Mock implements ConfigurationBloc {}

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(SenseBox(
      sId: 'fallback',
      name: 'Fallback',
      exposure: 'outdoor',
      sensors: [],
    ));
    setupSensorCatalogFromRepo();
  });

  tearDownAll(clearMockSensorCatalog);

  group('OpenSenseMapBloc', () {
    late OpenSenseMapBloc bloc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});

      bloc = OpenSenseMapBloc();
    });

    group('Initialization', () {
      test('should initialize with correct initial state', () {
        expect(bloc.isAuthenticated, false);
        expect(bloc.isAuthenticating, false);
        expect(bloc.selectedSenseBox, isNull);
        expect(bloc.senseBoxes, isEmpty);
      });

      test('should register as lifecycle observer', () {
        expect(bloc, isA<WidgetsBindingObserver>());
      });
    });

    group('API URL Configuration', () {
      test('should use default API URL when SettingsBloc has no custom URL',
          () async {
        final settingsBloc = SettingsBloc();
        // Wait for settings to load
        await Future.delayed(const Duration(milliseconds: 100));

        final blocWithDefaultSettings =
            OpenSenseMapBloc(settingsBloc: settingsBloc);
        expect(blocWithDefaultSettings, isA<OpenSenseMapBloc>());
        expect(blocWithDefaultSettings.isAuthenticated, false);

        // SettingsBloc should return default URL
        expect(settingsBloc.apiUrl, 'https://api.opensensemap.org');
        
        blocWithDefaultSettings.dispose();
      });

      test('should use custom API URL from SettingsBloc when stored', () async {
        final settingsBloc = SettingsBloc();
        // Wait for SettingsBloc to finish loading
        await Future.delayed(const Duration(milliseconds: 100));
        
        const customUrl = 'https://custom-api.example.com';

        // Set custom URL in settings
        await settingsBloc.setApiUrl(customUrl);

        final blocWithCustomSettings =
            OpenSenseMapBloc(settingsBloc: settingsBloc);
        expect(blocWithCustomSettings, isA<OpenSenseMapBloc>());

        // SettingsBloc should return the custom URL
        expect(settingsBloc.apiUrl, customUrl);
        
        blocWithCustomSettings.dispose();
        settingsBloc.dispose();
      });

      test('should persist API URL in shared preferences', () async {
        final settingsBloc = SettingsBloc();
        // Wait for initial load
        await Future.delayed(const Duration(milliseconds: 100));
        
        const customUrl = 'https://test-api.example.com';

        // Set custom URL
        await settingsBloc.setApiUrl(customUrl);

        // Create new SettingsBloc instance to simulate app restart
        final newSettingsBloc = SettingsBloc();
        await Future.delayed(
            const Duration(milliseconds: 100)); // Wait for loading

        // Should load the stored URL
        expect(newSettingsBloc.apiUrl, customUrl);
        
        settingsBloc.dispose();
        newSettingsBloc.dispose();
      });

      test('should fallback to default when stored URL is empty', () async {
        final settingsBloc = SettingsBloc();
        // Wait for initial load
        await Future.delayed(const Duration(milliseconds: 100));

        // Set empty URL
        await settingsBloc.setApiUrl('');

        // Should return default URL
        expect(settingsBloc.apiUrl, 'https://api.opensensemap.org');
        
        settingsBloc.dispose();
      });
    });

    group('SenseBox Management', () {
      test('should set selected sensebox correctly', () async {
        final testBox = SenseBox(
            sId: '1', name: 'Test Box', exposure: 'outdoor', sensors: []);

        await bloc.setSelectedSenseBox(testBox);

        expect(bloc.selectedSenseBox, testBox);
      });

      test('should clear selected sensebox when null is passed', () async {
        final testBox = SenseBox(
            sId: '1', name: 'Test Box', exposure: 'outdoor', sensors: []);

        await bloc.setSelectedSenseBox(testBox);
        expect(bloc.selectedSenseBox, testBox);

        await bloc.setSelectedSenseBox(null);
        expect(bloc.selectedSenseBox, isNull);
      });


      test('should clear selected sensebox when not authenticated', () async {
        final testBox = SenseBox(
            sId: '1', name: 'Test Box', exposure: 'outdoor', sensors: []);

        await bloc.setSelectedSenseBox(testBox);
        expect(bloc.selectedSenseBox, testBox);

        await bloc.loadSelectedSenseBox();

        expect(bloc.selectedSenseBox, isNull);
      });
    });

    group('buildSenseBoxBikeModel()', () {
      test('creates model with all components', () {
        final boxConfig = BoxConfiguration(
          id: 'atrai',
          displayName: 'Atrai',
          defaultGrouptag: 'atrai',
          sensors: [
            SensorDefinition(
              key: 'temperature',
              id: '1',
              icon: 'osem-thermometer',
              title: 'Temperature',
              unit: '°C',
              sensorType: 'HDC1080',
            ),
            SensorDefinition(
              key: 'humidity',
              id: '2',
              icon: 'osem-humidity',
              title: 'Rel. Humidity',
              unit: '%',
              sensorType: 'HDC1080',
            ),
          ],
        );

        final model = bloc.buildSenseBoxBikeModel(
          'Test Box',
          13.4050,
          52.5200,
          boxConfig,
          'selected-tag',
          ['foo', 'bar', null, 'baz'],
        );

        expect(model['name'], 'Test Box');
        expect(model['exposure'], 'mobile');
        expect(model['location'], [13.4050, 52.5200]);
        
        final tags = model['grouptag'] as List;
        expect(tags, contains('bike'));
        expect(tags, contains('atrai'));
        expect(tags, contains('selected-tag'));
        expect(tags, contains('foo'));
        expect(tags, contains('bar'));
        expect(tags, contains('baz'));
        expect(tags.length, 6);
        
        expect(model['sensors'], isA<List>());
        final sensors = model['sensors'] as List;
        expect(sensors.length, 2);
        expect(sensors[0]['title'], 'Temperature');
        expect(sensors[1]['title'], 'Rel. Humidity');
      });
    });

    group('Box Compatibility', () {
      late MockConfigurationBloc mockConfigurationBloc;

      setUp(() {
        mockConfigurationBloc = MockConfigurationBloc();
      });

      group('loadSelectedSenseBox()', () {
        test('preserves saved box from preferences', () async {
          SharedPreferences.setMockInitialValues({});
          final mockService = MockOpenSenseMapService();
          final bloc = OpenSenseMapBloc(
            configurationBloc: mockConfigurationBloc,
            service: mockService,
          );

          final savedBox = SenseBox(
            sId: 'saved-box',
            name: 'Saved Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Unknown Sensor', unit: '?', sensorType: 'UNKNOWN'),
            ],
            grouptag: [],
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'selectedSenseBox', jsonEncode(savedBox.toJson()));

          when(() => mockService.isCurrentAccessTokenValid())
              .thenAnswer((_) async => true);

          await bloc.performAuthenticationCheck();

          expect(bloc.selectedSenseBox?.sId, 'saved-box');
        });

        test('loads saved box when ConfigurationBloc is null', () async {
          SharedPreferences.setMockInitialValues({});
          final mockService = MockOpenSenseMapService();
          final bloc = OpenSenseMapBloc(service: mockService);

          final box = SenseBox(
            sId: 'saved-box',
            name: 'Saved Box',
            exposure: 'outdoor',
            sensors: [],
            grouptag: [],
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selectedSenseBox', jsonEncode(box.toJson()));

          when(() => mockService.isCurrentAccessTokenValid())
              .thenAnswer((_) async => true);

          await bloc.performAuthenticationCheck();

          expect(bloc.selectedSenseBox?.sId, 'saved-box');
        });
      });

      group('login() box selection', () {
        test('selects first box when multiple boxes available', () async {
          SharedPreferences.setMockInitialValues({});
          final mockService = MockOpenSenseMapService();

          final firstBox = SenseBox(
            sId: 'box-1',
            name: 'First Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Temperature', unit: '°C', sensorType: 'HDC1080'),
            ],
            grouptag: [],
          );

          final secondBox = SenseBox(
            sId: 'box-2',
            name: 'Second Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Unknown Sensor', unit: '?', sensorType: 'UNKNOWN'),
            ],
            grouptag: [],
          );

          when(() => mockService.removeTokens()).thenAnswer((_) async => {});
          when(() => mockService.login(any(), any())).thenAnswer((_) async => {
                'data': {
                  'user': {
                    'boxes': ['box-1', 'box-2']
                  }
                }
              });
          when(() => mockService.getSenseBoxes(page: 0))
              .thenAnswer((_) async => [
                    firstBox.toJson(),
                    secondBox.toJson(),
                  ]);

          final bloc = OpenSenseMapBloc(
            configurationBloc: mockConfigurationBloc,
            service: mockService,
          );

          await bloc.login('test@example.com', 'password');

          expect(bloc.selectedSenseBox?.sId, 'box-1');
        });

        test('selects first box even when sensors are unknown', () async {
          SharedPreferences.setMockInitialValues({});
          final mockService = MockOpenSenseMapService();

          final box = SenseBox(
            sId: 'incompatible-1',
            name: 'Any Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Unknown Sensor', unit: '?', sensorType: 'UNKNOWN'),
            ],
            grouptag: [],
          );

          when(() => mockService.removeTokens()).thenAnswer((_) async => {});
          when(() => mockService.login(any(), any())).thenAnswer((_) async => {
                'data': {
                  'user': {
                    'boxes': ['incompatible-1']
                  }
                }
              });
          when(() => mockService.getSenseBoxes(page: 0))
              .thenAnswer((_) async => [box.toJson()]);

          final bloc = OpenSenseMapBloc(
            configurationBloc: mockConfigurationBloc,
            service: mockService,
          );

          await bloc.login('test@example.com', 'password');

          expect(bloc.selectedSenseBox?.sId, 'incompatible-1');
        });

        test('falls back to first box when ConfigurationBloc is null',
            () async {
          SharedPreferences.setMockInitialValues({});
          final mockService = MockOpenSenseMapService();

          final box = SenseBox(
            sId: 'box-1',
            name: 'Test Box',
            exposure: 'outdoor',
            sensors: [],
            grouptag: [],
          );

          when(() => mockService.removeTokens()).thenAnswer((_) async => {});
          when(() => mockService.login(any(), any())).thenAnswer((_) async => {
                'data': {
                  'user': {
                    'boxes': ['box-1']
                  }
                }
              });
          when(() => mockService.getSenseBoxes(page: 0))
              .thenAnswer((_) async => [box.toJson()]);

          final bloc = OpenSenseMapBloc(service: mockService);

          await bloc.login('test@example.com', 'password');

          expect(bloc.selectedSenseBox?.sId, 'box-1');
        });
      });
    });
  });
}
