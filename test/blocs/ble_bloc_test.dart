import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import '../mocks.dart';

void main() {
  group('BleBloc', () {
    late BleBloc bleBloc;

    setUpAll(() {
      registerFallbackValue(MockBluetoothDevice());
      registerFallbackValue(FakeBuildContext());
    });

    setUp(() {
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
      });
    });

    group('Bluetooth Status', () {
      test('updateBluetoothStatus updates notifier', () {
        bleBloc.updateBluetoothStatus(true);

        expect(bleBloc.isBluetoothEnabledNotifier.value, isTrue);
      });
    });

    group('Connection State Management', () {
      test('resetConnectionError clears connection error state', () {
        bleBloc.connectionErrorNotifier.value = true;
        bleBloc.resetConnectionError();
        expect(bleBloc.connectionErrorNotifier.value, isFalse);
      });
    });

    group('Device Management', () {
      test('devicesListStream provides stream of device lists', () {
        expect(bleBloc.devicesListStream, isA<Stream<List<dynamic>>>());
      });

      test('startScanning disconnects when a device is selected', () {
        final mockDevice = MockBluetoothDevice();
        bleBloc.selectedDevice = mockDevice;
        bleBloc.selectedDeviceNotifier.value = mockDevice;

        bleBloc.startScanning();

        expect(bleBloc.selectedDevice, isNull);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
      });
    });
  });
}

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

class FakeBuildContext extends Fake implements BuildContext {}
