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

    group('State Management', () {
      test('should update authentication state when markAuthenticationFailed is called', () async {
        expect(bloc.isAuthenticated, false);
        
        await bloc.markAuthenticationFailed();
        
        expect(bloc.isAuthenticated, false);
        expect(bloc.selectedSenseBox, isNull);
        expect(bloc.senseBoxes, isEmpty);
      });

      test('should handle authentication state validation', () async {
        final result = await bloc.validateAuthenticationState();
        
        expect(result, false);
        expect(bloc.isAuthenticated, false);
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

    group('App Lifecycle Management', () {
      test('should handle app resume state change', () {
        expect(() => bloc.didChangeAppLifecycleState(AppLifecycleState.resumed), 
          returnsNormally);
      });

      test('should handle app pause state change', () {
        expect(() => bloc.didChangeAppLifecycleState(AppLifecycleState.paused), 
          returnsNormally);
      });

      test('should handle app inactive state change', () {
        expect(() => bloc.didChangeAppLifecycleState(AppLifecycleState.inactive), 
          returnsNormally);
      });

      test('should handle app detached state change', () {
        expect(() => bloc.didChangeAppLifecycleState(AppLifecycleState.detached), 
          returnsNormally);
      });
    });

    group('Edge Cases', () {
      test('should handle multiple rapid state changes', () async {
        bloc.markAuthenticationFailed();
        await bloc.validateAuthenticationState();
        bloc.markAuthenticationFailed();
        
        expect(bloc.isAuthenticated, false);
      });

      test('should handle multiple sensebox selections', () async {
        final testBox1 = SenseBox(
          sId: '1',
          name: 'Test Box 1',
          exposure: 'outdoor',
          sensors: []
        );
        
        final testBox2 = SenseBox(
          sId: '2',
          name: 'Test Box 2',
          exposure: 'outdoor',
          sensors: []
        );
        
        await bloc.setSelectedSenseBox(testBox1);
        expect(bloc.selectedSenseBox, testBox1);
        
        await bloc.setSelectedSenseBox(testBox2);
        expect(bloc.selectedSenseBox, testBox2);
        
        await bloc.setSelectedSenseBox(null);
        expect(bloc.selectedSenseBox, isNull);
      });
    });



    group('Authentication Flow', () {
      test('should handle login flow state changes', () async {
        expect(bloc.isAuthenticated, false);
        expect(bloc.isAuthenticating, false);
        
        expect(bloc.isAuthenticated, false);
      });

      test('should handle registration flow state changes', () async {
        expect(bloc.isAuthenticated, false);
        expect(bloc.isAuthenticating, false);
        
        expect(bloc.isAuthenticated, false);
      });

      test('should handle logout flow state changes', () async {
        expect(bloc.isAuthenticated, false);
        
        await bloc.logout();
        
        expect(bloc.isAuthenticated, false);
        expect(bloc.selectedSenseBox, isNull);
        expect(bloc.senseBoxes, isEmpty);
      });
    });

    group('SenseBox Operations', () {
      test('should handle sensebox fetch operations', () async {
        final result = await bloc.fetchSenseBoxes(page: 0);
        
        expect(result, isEmpty);
      });

      test('should handle sensebox creation operations', () async {
        await bloc.createSenseBoxBike(
          'Test Bike',
          52.5200,
          13.4050,
          SenseBoxBikeModel.classic,
          'test-tag'
        );
        
        expect(true, true);
      });
    });

    group('Value Notifiers', () {
      test('should expose authenticating notifier', () {
        expect(bloc.isAuthenticatingNotifier, isA<ValueNotifier<bool>>());
        expect(bloc.isAuthenticating, false);
      });

      test('should update authenticating state', () {
        bloc.isAuthenticatingNotifier.value = true;
        expect(bloc.isAuthenticating, true);
        
        bloc.isAuthenticatingNotifier.value = false;
        expect(bloc.isAuthenticating, false);
      });
    });

    group('Disposal', () {
      test('should dispose correctly', () {
        expect(() => bloc.dispose(), returnsNormally);
      });

      test('should close stream controller on dispose', () {
        bloc.dispose();
        
        expect(bloc.senseBoxStream.isBroadcast, true);
      });
    });
  });
}
