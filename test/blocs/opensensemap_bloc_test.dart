import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';

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
          sId: '1',
          name: 'Test Box',
          exposure: 'outdoor',
          sensors: []
        );
        
        await bloc.setSelectedSenseBox(testBox);
        
        expect(bloc.selectedSenseBox, testBox);
      });

      test('should clear selected sensebox when null is passed', () async {
        final testBox = SenseBox(
          sId: '1',
          name: 'Test Box',
          exposure: 'outdoor',
          sensors: []
        );
        
        await bloc.setSelectedSenseBox(testBox);
        expect(bloc.selectedSenseBox, testBox);
        
        await bloc.setSelectedSenseBox(null);
        expect(bloc.selectedSenseBox, isNull);
      });

      test('should load selected sensebox from preferences', () async {
        final testBox = SenseBox(
          sId: '1',
          name: 'Test Box',
          exposure: 'outdoor',
          sensors: []
        );
        
        await bloc.setSelectedSenseBox(testBox);
        
        expect(bloc.selectedSenseBox, testBox);
      });

      test('should clear selected sensebox when not authenticated', () async {
        final testBox = SenseBox(
          sId: '1',
          name: 'Test Box',
          exposure: 'outdoor',
          sensors: []
        );
        
        await bloc.setSelectedSenseBox(testBox);
        expect(bloc.selectedSenseBox, testBox);
        
        await bloc.loadSelectedSenseBox();
        
        expect(bloc.selectedSenseBox, isNull);
      });
    });

    group('Stream Management', () {
      test('should emit selected sensebox through stream', () async {
        final testBox = SenseBox(
          sId: '1',
          name: 'Test Box',
          exposure: 'outdoor',
          sensors: []
        );
        
        final emittedValues = <SenseBox?>[];
        bloc.senseBoxStream.listen(emittedValues.add);
        
        await bloc.setSelectedSenseBox(testBox);
        
        await Future.delayed(Duration(milliseconds: 100));
        
        expect(emittedValues, contains(testBox));
      });

      test('should emit null when sensebox is cleared', () async {
        final testBox = SenseBox(
          sId: '1',
          name: 'Test Box',
          exposure: 'outdoor',
          sensors: []
        );
        
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
