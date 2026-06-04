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

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerFallbackValue(MockBluetoothDevice());
      registerFallbackValue(FakeBuildContext());
    });

    setUp(() {
      mockSettingsBloc = MockSettingsBloc();
      bleBloc = MockBleBloc();
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
        bleBloc.connectionErrorNotifier.value = true;
        bleBloc.resetConnectionError();
        expect(bleBloc.connectionErrorNotifier.value, isFalse);
      });


    });

    group('Error Handling', () {
      test('connectionErrorNotifier can be set and reset', () {
        bleBloc.connectionErrorNotifier.value = true;
        expect(bleBloc.connectionErrorNotifier.value, isTrue);
        
        bleBloc.resetConnectionError();
        expect(bleBloc.connectionErrorNotifier.value, isFalse);
      });

      test('linkOnly disconnect keeps selected device and reconnecting state',
          () async {
        final realBleBloc = BleBloc(
          mockSettingsBloc,
          initializePlatformBle: false,
        );
        addTearDown(realBleBloc.dispose);

        final mockDevice = MockBluetoothDevice();
        when(() => mockDevice.disconnect()).thenAnswer((_) async {});
        realBleBloc.selectedDevice = mockDevice;
        realBleBloc.selectedDeviceNotifier.value = mockDevice;
        realBleBloc.isReconnectingNotifier.value = true;

        await realBleBloc.disconnectDevice(device: mockDevice, linkOnly: true);

        expect(realBleBloc.selectedDevice, mockDevice);
        expect(realBleBloc.selectedDeviceNotifier.value, mockDevice);
        expect(realBleBloc.isReconnectingNotifier.value, isTrue);
      });

      test('shows connection error when device.connect throws on initial connect',
          () async {
        final realBleBloc = BleBloc(
          mockSettingsBloc,
          initializePlatformBle: false,
        );
        addTearDown(realBleBloc.dispose);

        final mockDevice = MockBluetoothDevice();
        when(() => mockDevice.connect()).thenThrow(Exception('Connection failed'));

        await realBleBloc.connectToDevice(mockDevice, FakeBuildContext());

        expect(realBleBloc.connectionErrorNotifier.value, isTrue);
        expect(realBleBloc.isConnectingNotifier.value, isFalse);
        expect(realBleBloc.selectedDeviceNotifier.value, isNull);
        expect(realBleBloc.isConnected, isFalse);
      });
    });

    group('Device Management', () {
      test('devicesListStream provides stream of device lists', () {
        expect(bleBloc.devicesListStream, isA<Stream<List<dynamic>>>());
      });

      test('scanForNewDevices clears selected device', () {
        final mockDevice = MockBluetoothDevice();
        bleBloc.selectedDevice = mockDevice;
        bleBloc.selectedDeviceNotifier.value = mockDevice;
        
        bleBloc.scanForNewDevices();
        
        expect(bleBloc.selectedDevice, isNull);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
      });
    });
  });
}

class MockBluetoothDevice extends Mock implements BluetoothDevice {}
class FakeBuildContext extends Fake implements BuildContext {}

