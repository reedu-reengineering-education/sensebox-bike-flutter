import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:mocktail/mocktail.dart';

class MockConfigurationBloc extends Mock implements ConfigurationBloc {}

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
        test('preserves compatible saved box when loading', () async {
          SharedPreferences.setMockInitialValues({});
          final bloc =
              OpenSenseMapBloc(configurationBloc: mockConfigurationBloc);

          final compatibleBox = SenseBox(
            sId: 'saved-compatible',
            name: 'Saved Compatible Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Temperature', unit: '°C', sensorType: 'HDC1080'),
            ],
            grouptag: [],
          );

          await bloc.setSelectedSenseBox(compatibleBox);

          final prefs = await SharedPreferences.getInstance();
          final savedBoxJson = await prefs.getString('selectedSenseBox');
          expect(savedBoxJson, isNotNull);

          when(() => mockConfigurationBloc.isSenseBoxBikeCompatible(any()))
              .thenReturn(true);

          final savedBox = SenseBox.fromJson(jsonDecode(savedBoxJson!));
          final isCompatible =
              mockConfigurationBloc.isSenseBoxBikeCompatible(savedBox);

          expect(isCompatible, true);
          expect(savedBox.sId, 'saved-compatible');
        });

        test('identifies incompatible saved box', () async {
          SharedPreferences.setMockInitialValues({});
          final bloc =
              OpenSenseMapBloc(configurationBloc: mockConfigurationBloc);

          final incompatibleBox = SenseBox(
            sId: 'saved-incompatible',
            name: 'Saved Incompatible Box',
            exposure: 'outdoor',
            sensors: [
              Sensor(title: 'Unknown Sensor', unit: '?', sensorType: 'UNKNOWN'),
            ],
            grouptag: [],
          );

          await bloc.setSelectedSenseBox(incompatibleBox);

          final prefs = await SharedPreferences.getInstance();
          final savedBoxJson = await prefs.getString('selectedSenseBox');
          expect(savedBoxJson, isNotNull);

          when(() => mockConfigurationBloc.isSenseBoxBikeCompatible(any()))
              .thenReturn(false);

          final savedBox = SenseBox.fromJson(jsonDecode(savedBoxJson!));
          final isCompatible =
              mockConfigurationBloc.isSenseBoxBikeCompatible(savedBox);

          expect(isCompatible, false);
        });

        test('works when ConfigurationBloc is null', () async {
          SharedPreferences.setMockInitialValues({});
          final bloc = OpenSenseMapBloc();

          final box = SenseBox(
            sId: 'saved-box',
            name: 'Saved Box',
            exposure: 'outdoor',
            sensors: [],
            grouptag: [],
          );

          await bloc.setSelectedSenseBox(box);

          final prefs = await SharedPreferences.getInstance();
          final savedBoxJson = await prefs.getString('selectedSenseBox');
          expect(savedBoxJson, isNotNull);

          final savedBox = SenseBox.fromJson(jsonDecode(savedBoxJson!));
          expect(savedBox.sId, 'saved-box');
        });
      });
    });
  });
}
