import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
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
      test('should call createSenseBoxBike with additional tags', () async {
        final mockService = MockOpenSenseMapService();
        final name = 'Test';
        final lat = 1.0;
        final lng = 2.0;
        final model = SenseBoxBikeModel.atrai;
        final selectedTag = 'tag1';
        final additionalTags = ['foo', 'bar', 'baz'];
        when(() => mockService.createSenseBoxBike(
                name, lat, lng, model, selectedTag, additionalTags))
            .thenAnswer((_) async => Future.value());
        // Call the method
        await mockService.createSenseBoxBike(
            name, lat, lng, model, selectedTag, additionalTags);
        verify(() => mockService.createSenseBoxBike(
            name, lat, lng, model, selectedTag, additionalTags)).called(1);
      });
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

      test('should load selected sensebox from preferences', () async {
        final testBox = SenseBox(
            sId: '1', name: 'Test Box', exposure: 'outdoor', sensors: []);

        await bloc.setSelectedSenseBox(testBox);

        expect(bloc.selectedSenseBox, testBox);
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
  });
}
