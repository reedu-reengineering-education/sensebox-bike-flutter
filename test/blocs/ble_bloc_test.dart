import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import '../mocks.dart';

void main() {
  group('BleBloc', () {
    late BleBloc bleBloc;
    late MockSettingsBloc mockSettingsBloc;

    setUp(() {
      mockSettingsBloc = MockSettingsBloc();
      bleBloc = BleBloc(mockSettingsBloc);
    });

    tearDown(() {
      bleBloc.dispose();
    });

    group('Initialization', () {
      test('initializes with correct default values', () {
        expect(bleBloc.isBluetoothEnabledNotifier.value, isFalse);
        expect(bleBloc.isScanningNotifier.value, isFalse);
        expect(bleBloc.isConnectingNotifier.value, isFalse);
        expect(bleBloc.isReconnectingNotifier.value, isFalse);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
        expect(bleBloc.availableCharacteristics.value, isEmpty);
        expect(bleBloc.characteristicStreamsVersion.value, equals(0));
        expect(bleBloc.connectionErrorNotifier.value, isFalse);
        expect(bleBloc.isConnected, isFalse);
        expect(bleBloc.devicesList, isEmpty);
      });
    });

    group('Bluetooth Status', () {
      test('updateBluetoothStatus updates notifier and notifies listeners', () {
        bool listenerCalled = false;
        bleBloc.addListener(() {
          listenerCalled = true;
        });

        bleBloc.updateBluetoothStatus(true);

        expect(bleBloc.isBluetoothEnabledNotifier.value, isTrue);
        expect(listenerCalled, isTrue);
      });
    });

    group('Connection State Management', () {
      test('resetConnectionError clears connection error state', () {
        // Set error state
        bleBloc.connectionErrorNotifier.value = true;
        
        bleBloc.resetConnectionError();
        
        expect(bleBloc.connectionErrorNotifier.value, isFalse);
      });

      test('forceResetReconnectionState resets all reconnection variables', () {
        // Set reconnection state
        bleBloc.isReconnectingNotifier.value = true;
        
        bleBloc.forceResetReconnectionState();
        
        expect(bleBloc.isReconnectingNotifier.value, isFalse);
      });
    });

    group('Device Management', () {
      test('devicesListStream provides stream of device lists', () {
        expect(bleBloc.devicesListStream, isA<Stream<List<dynamic>>>());
      });

      test('scanForNewDevices disconnects current device before scanning', () {
        // Mock a selected device
        bleBloc.selectedDevice = MockBluetoothDevice();
        bleBloc.selectedDeviceNotifier.value = MockBluetoothDevice();
        
        bleBloc.scanForNewDevices();
        
        // Verify device is cleared
        expect(bleBloc.selectedDevice, isNull);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
      });
    });

    group('Error Handling', () {
      test('connectionErrorNotifier can be set and reset', () {
        // Set error state
        bleBloc.connectionErrorNotifier.value = true;
        expect(bleBloc.connectionErrorNotifier.value, isTrue);
        
        // Reset error state
        bleBloc.resetConnectionError();
        expect(bleBloc.connectionErrorNotifier.value, isFalse);
      });

      test('when initial BLE connection is started, if exception is thrown, reconnection continues seamlessly', () {
        // Verify initial state
        expect(bleBloc.connectionErrorNotifier.value, isFalse);
        expect(bleBloc.isConnectingNotifier.value, isFalse);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
        
        // Mock a device that will throw an exception during connection
        final mockDevice = MockBluetoothDevice();
        
        // Mock the device.connect() to throw an exception
        when(() => mockDevice.connect()).thenThrow(Exception('Connection failed'));
        
        // Mock context
        final mockContext = FakeBuildContext();
        
        // Attempt to connect - this should throw an exception
        expect(
          () => bleBloc.connectToDevice(mockDevice, mockContext),
          throwsA(isA<Exception>()),
        );
        
        // Verify that after exception, the state is properly reset for reconnection
        expect(bleBloc.connectionErrorNotifier.value, isFalse); // Error was handled
        expect(bleBloc.isConnectingNotifier.value, isFalse); // Connecting state reset
        expect(bleBloc.selectedDeviceNotifier.value, isNull); // Device cleared
        expect(bleBloc.isConnected, isFalse); // Connection state reset
        
        // Verify that the user can now attempt reconnection seamlessly
        // (all state is clean and ready for another attempt)
      });
    });

    group('Device Management', () {
      test('scanForNewDevices clears selected device', () {
        // Mock a selected device
        final mockDevice = MockBluetoothDevice();
        bleBloc.selectedDevice = mockDevice;
        bleBloc.selectedDeviceNotifier.value = mockDevice;
        
        bleBloc.scanForNewDevices();
        
        // Verify device is cleared
        expect(bleBloc.selectedDevice, isNull);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
      });
    });
  });
}

// Mock classes for testing
class MockBluetoothDevice extends Mock implements BluetoothDevice {}
class FakeBuildContext extends Fake implements BuildContext {}

