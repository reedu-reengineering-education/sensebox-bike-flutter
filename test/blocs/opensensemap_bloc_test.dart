import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:mocktail/mocktail.dart';

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    group('Stream Management', () {
      test('should emit selected sensebox through stream', () async {
        final testBox = SenseBox(
            sId: '1', name: 'Test Box', exposure: 'outdoor', sensors: []);

        final emittedValues = <SenseBox?>[];
        bloc.senseBoxStream.listen(emittedValues.add);

        await bloc.setSelectedSenseBox(testBox);

        await Future.delayed(Duration(milliseconds: 100));

        expect(emittedValues, contains(testBox));
      });

      test('should emit null when sensebox is cleared', () async {
        final testBox = SenseBox(
            sId: '1', name: 'Test Box', exposure: 'outdoor', sensors: []);

        final emittedValues = <SenseBox?>[];
        bloc.senseBoxStream.listen(emittedValues.add);

        await bloc.setSelectedSenseBox(testBox);
        await bloc.setSelectedSenseBox(null);

        await Future.delayed(Duration(milliseconds: 100));

        expect(emittedValues, contains(null));
      });
    });

    group('buildSenseBoxBikeModel()', () {
      test('creates model with default tags', () {
        final boxConfig = BoxConfiguration(
          id: 'classic',
          displayName: 'Classic',
          defaultGrouptag: 'classic',
          sensors: [
            SensorDefinition(
              id: '1',
              icon: 'osem-thermometer',
              title: 'Temperature',
              unit: '°C',
              sensorType: 'HDC1080',
            ),
          ],
        );

        final model = bloc.buildSenseBoxBikeModel(
          'Test Box',
          52.5200,
          13.4050,
          boxConfig,
          null,
          [],
        );

        expect(model['name'], 'Test Box');
        expect(model['exposure'], 'mobile');
        expect(model['location'], [52.5200, 13.4050]);
        expect(model['grouptag'], ['bike', 'classic']);
        expect(model['sensors'], isA<List>());
        expect((model['sensors'] as List).length, 1);
      });

      test('adds selected tag to grouptags', () {
        final boxConfig = BoxConfiguration(
          id: 'classic',
          displayName: 'Classic',
          defaultGrouptag: 'classic',
          sensors: [],
        );

        final model = bloc.buildSenseBoxBikeModel(
          'Test Box',
          52.5200,
          13.4050,
          boxConfig,
          'custom-tag',
          [],
        );

        expect(model['grouptag'], ['bike', 'classic', 'custom-tag']);
      });

      test('ignores empty selected tag', () {
        final boxConfig = BoxConfiguration(
          id: 'classic',
          displayName: 'Classic',
          defaultGrouptag: 'classic',
          sensors: [],
        );

        final model = bloc.buildSenseBoxBikeModel(
          'Test Box',
          52.5200,
          13.4050,
          boxConfig,
          '',
          [],
        );

        expect(model['grouptag'], ['bike', 'classic']);
      });

      test('adds additional tags to grouptags', () {
        final boxConfig = BoxConfiguration(
          id: 'atrai',
          displayName: 'Atrai',
          defaultGrouptag: 'atrai',
          sensors: [],
        );

        final model = bloc.buildSenseBoxBikeModel(
          'Test Box',
          52.5200,
          13.4050,
          boxConfig,
          'selected-tag',
          ['foo', 'bar', null, 'baz'],
        );

        final tags = model['grouptag'] as List;
        expect(tags, contains('bike'));
        expect(tags, contains('atrai'));
        expect(tags, contains('selected-tag'));
        expect(tags, contains('foo'));
        expect(tags, contains('bar'));
        expect(tags, contains('baz'));
        expect(tags.length, 6);
      });

      test('filters out null values from additional tags', () {
        final boxConfig = BoxConfiguration(
          id: 'classic',
          displayName: 'Classic',
          defaultGrouptag: 'classic',
          sensors: [],
        );

        final model = bloc.buildSenseBoxBikeModel(
          'Test Box',
          52.5200,
          13.4050,
          boxConfig,
          null,
          ['valid', null, 'also-valid', null],
        );

        final tags = model['grouptag'] as List;
        expect(tags, contains('bike'));
        expect(tags, contains('classic'));
        expect(tags, contains('valid'));
        expect(tags, contains('also-valid'));
        expect(tags.length, 4);
      });

      test('includes sensors from box configuration', () {
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
          52.5200,
          13.4050,
          boxConfig,
          null,
          [],
        );

        expect(model['sensors'], isA<List>());
        final sensors = model['sensors'] as List;
        expect(sensors.length, 2);
        expect(sensors[0]['title'], 'Temperature');
        expect(sensors[1]['title'], 'Rel. Humidity');
      });

    });
  });
}
