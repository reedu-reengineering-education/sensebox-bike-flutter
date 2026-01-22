import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:mocktail/mocktail.dart';

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
  });

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
              id: '1',
              icon: 'osem-thermometer',
              title: 'Temperature',
              unit: '°C',
              sensorType: 'HDC1080',
            ),
            SensorDefinition(
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

      group('loadSelectedSenseBox() compatibility checking', () {
        test('clears incompatible saved box from preferences', () async {
          SharedPreferences.setMockInitialValues({});
          final mockService = MockOpenSenseMapService();
          final bloc = OpenSenseMapBloc(
            configurationBloc: mockConfigurationBloc,
            service: mockService,
          );

          final incompatibleBox = SenseBox(
            sId: 'saved-incompatible',
            name: 'Saved Incompatible Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Unknown Sensor', unit: '?', sensorType: 'UNKNOWN'),
            ],
            grouptag: [],
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'selectedSenseBox', jsonEncode(incompatibleBox.toJson()));

          when(() => mockConfigurationBloc.isSenseBoxBikeCompatible(any()))
              .thenReturn(false);
          when(() => mockService.isCurrentAccessTokenValid())
              .thenAnswer((_) async => true);

          await bloc.performAuthenticationCheck();

          expect(bloc.selectedSenseBox, isNull);
          final savedBoxJson = await prefs.getString('selectedSenseBox');
          expect(savedBoxJson, isNull);
        });

        test('preserves compatible saved box when loading', () async {
          SharedPreferences.setMockInitialValues({});
          final mockService = MockOpenSenseMapService();
          final bloc = OpenSenseMapBloc(
            configurationBloc: mockConfigurationBloc,
            service: mockService,
          );

          final compatibleBox = SenseBox(
            sId: 'saved-compatible',
            name: 'Saved Compatible Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Temperature', unit: '°C', sensorType: 'HDC1080'),
            ],
            grouptag: [],
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'selectedSenseBox', jsonEncode(compatibleBox.toJson()));

          when(() => mockConfigurationBloc.isSenseBoxBikeCompatible(any()))
              .thenReturn(true);
          when(() => mockService.isCurrentAccessTokenValid())
              .thenAnswer((_) async => true);

          await bloc.performAuthenticationCheck();

          expect(bloc.selectedSenseBox?.sId, 'saved-compatible');
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

      group('login() compatibility checking', () {
        test('selects first compatible box when multiple boxes available',
            () async {
          SharedPreferences.setMockInitialValues({});
          final mockService = MockOpenSenseMapService();

          final compatibleBox = SenseBox(
            sId: 'compatible-1',
            name: 'Compatible Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Temperature', unit: '°C', sensorType: 'HDC1080'),
            ],
            grouptag: [],
          );

          final incompatibleBox = SenseBox(
            sId: 'incompatible-1',
            name: 'Incompatible Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Unknown Sensor', unit: '?', sensorType: 'UNKNOWN'),
            ],
            grouptag: [],
          );

          when(() => mockConfigurationBloc.isSenseBoxBikeCompatible(any()))
              .thenAnswer((invocation) {
            final box = invocation.positionalArguments[0] as SenseBox;
            return box.sId == 'compatible-1';
          });

          when(() => mockService.removeTokens()).thenAnswer((_) async => {});
          when(() => mockService.login(any(), any())).thenAnswer((_) async => {
                'data': {
                  'user': {
                    'boxes': ['compatible-1', 'incompatible-1']
                  }
                }
              });
          when(() => mockService.getSenseBoxes(page: 0))
              .thenAnswer((_) async => [
                    compatibleBox.toJson(),
                    incompatibleBox.toJson(),
                  ]);

          final bloc = OpenSenseMapBloc(
            configurationBloc: mockConfigurationBloc,
            service: mockService,
          );

          await bloc.login('test@example.com', 'password');

          expect(bloc.selectedSenseBox?.sId, 'compatible-1');
          verify(() => mockConfigurationBloc.isSenseBoxBikeCompatible(any()))
              .called(greaterThan(0));
        });

        test('does not select box when no compatible boxes available',
            () async {
          SharedPreferences.setMockInitialValues({});
          final mockService = MockOpenSenseMapService();

          final incompatibleBox = SenseBox(
            sId: 'incompatible-1',
            name: 'Incompatible Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Unknown Sensor', unit: '?', sensorType: 'UNKNOWN'),
            ],
            grouptag: [],
          );

          when(() => mockConfigurationBloc.isSenseBoxBikeCompatible(any()))
              .thenReturn(false);

          when(() => mockService.removeTokens()).thenAnswer((_) async => {});
          when(() => mockService.login(any(), any())).thenAnswer((_) async => {
                'data': {
                  'user': {
                    'boxes': ['incompatible-1']
                  }
                }
              });
          when(() => mockService.getSenseBoxes(page: 0))
              .thenAnswer((_) async => [incompatibleBox.toJson()]);

          final bloc = OpenSenseMapBloc(
            configurationBloc: mockConfigurationBloc,
            service: mockService,
          );

          await bloc.login('test@example.com', 'password');

          expect(bloc.selectedSenseBox, isNull);
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
