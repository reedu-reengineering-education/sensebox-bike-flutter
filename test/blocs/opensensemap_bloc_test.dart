import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:mocktail/mocktail.dart';
import '../sensor_catalog_test_data.dart';

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}

SenseBox _box(String id) =>
    SenseBox(sId: id, name: id, exposure: 'mobile', sensors: [], grouptag: []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(setupSensorCatalogFromRepo);
  tearDownAll(clearMockSensorCatalog);

  late MockOpenSenseMapService service;
  late OpenSenseMapBloc bloc;

  void stubLogin(List<SenseBox> boxes) {
    when(() => service.login(any(), any())).thenAnswer((_) async => {
          'data': {
            'user': {'boxes': boxes.map((b) => b.sId).toList()}
          }
        });
    when(() => service.getSenseBoxes(page: 0))
        .thenAnswer((_) async => boxes.map((b) => b.toJson()).toList());
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MockOpenSenseMapService();
    when(() => service.removeTokens()).thenAnswer((_) async {});
    when(() => service.logout()).thenAnswer((_) async {});
    bloc = OpenSenseMapBloc(service: service);
  });

  tearDown(() => bloc.dispose());

  test('initial state is logged out without boxes', () {
    expect(bloc.isAuthenticated, isFalse);
    expect(bloc.isAuthenticating, isFalse);
    expect(bloc.selectedSenseBox, isNull);
    expect(bloc.senseBoxes, isEmpty);
  });

  group('setSelectedSenseBox()', () {
    test('selects and persists a box', () async {
      await bloc.setSelectedSenseBox(_box('box-1'));

      expect(bloc.selectedSenseBox?.sId, 'box-1');
      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getString(SharedPreferencesKeys.selectedSenseBox), isNotNull);
    });

    test('null clears the selection and persisted box', () async {
      await bloc.setSelectedSenseBox(_box('box-1'));
      await bloc.setSelectedSenseBox(null);

      expect(bloc.selectedSenseBox, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SharedPreferencesKeys.selectedSenseBox), isNull);
    });
  });

  group('login()', () {
    test('selects the first box', () async {
      stubLogin([_box('box-1'), _box('box-2')]);

      await bloc.login('test@example.com', 'password');

      expect(bloc.isAuthenticated, isTrue);
      expect(bloc.selectedSenseBox?.sId, 'box-1');
    });

    test('clears a previously selected box when the user has none', () async {
      await bloc.setSelectedSenseBox(_box('old-box'));
      stubLogin([]);

      await bloc.login('test@example.com', 'password');

      expect(bloc.selectedSenseBox, isNull);
    });
  });

  group('performAuthenticationCheck()', () {
    setUp(() {
      when(() => service.isCurrentAccessTokenValid())
          .thenAnswer((_) async => true);
    });

    test('restores the saved box', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesKeys.selectedSenseBox:
            jsonEncode(_box('saved-box').toJson()),
      });

      await bloc.performAuthenticationCheck();

      expect(bloc.selectedSenseBox?.sId, 'saved-box');
    });

    test('selects the first box when none is saved', () async {
      stubLogin([_box('box-1')]);

      await bloc.performAuthenticationCheck();

      expect(bloc.selectedSenseBox?.sId, 'box-1');
    });
  });

  group('API URL change', () {
    late SettingsBloc settingsBloc;

    setUp(() async {
      settingsBloc = SettingsBloc();
      await Future.delayed(const Duration(milliseconds: 10));
      bloc = OpenSenseMapBloc(settingsBloc: settingsBloc, service: service);
      stubLogin([_box('box-1')]);
      await bloc.login('test@example.com', 'password');
    });

    tearDown(() => settingsBloc.dispose());

    test('logs out and clears the selected box', () async {
      await settingsBloc.setApiUrl('https://other-api.example.com');
      await Future.delayed(Duration.zero);

      expect(bloc.isAuthenticated, isFalse);
      expect(bloc.selectedSenseBox, isNull);
      verify(() => service.logout()).called(1);
    });

    test('keeps the session when the same URL is saved again', () async {
      await settingsBloc.setApiUrl(settingsBloc.apiUrl);
      await Future.delayed(Duration.zero);

      expect(bloc.isAuthenticated, isTrue);
      expect(bloc.selectedSenseBox?.sId, 'box-1');
      verifyNever(() => service.logout());
    });
  });

  test('buildSenseBoxBikeModel() builds the box payload', () {
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
      ['foo', 'bar', null, 'baz', 'bike'],
    );

    expect(model['name'], 'Test Box');
    expect(model['exposure'], 'mobile');
    expect(model['location'], [13.4050, 52.5200]);
    expect(model['grouptag'],
        ['bike', 'atrai', 'selected-tag', 'foo', 'bar', 'baz']);
    expect((model['sensors'] as List).map((s) => s['title']),
        ['Temperature', 'Rel. Humidity']);
  });
}
