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

    tearDown(() async {
      await bleBloc.close();
    });

    group('Initialization', () {
      test('initializes with correct default values', () {
        expect(bleBloc.state.isBluetoothEnabled, isFalse);
        expect(bleBloc.state.isScanning, isFalse);
        expect(bleBloc.state.isConnecting, isFalse);
        expect(bleBloc.state.isReconnecting, isFalse);
        expect(bleBloc.state.selectedDevice, isNull);
        expect(bleBloc.state.availableCharacteristics, isEmpty);
        expect(bleBloc.state.characteristicStreamsVersion, equals(0));
        expect(bleBloc.state.connectionError, isFalse);
        expect(bleBloc.isConnected, isFalse);
        expect(bleBloc.devicesList, isEmpty);
      });
    });

    group('Bluetooth Status', () {
      test('updateBluetoothStatus emits state transition', () async {
        final states = <BleState>[];
        final subscription = bleBloc.stream.listen(states.add);
        bleBloc.updateBluetoothStatus(true);
        await Future<void>.delayed(Duration.zero);

        expect(bleBloc.state.isBluetoothEnabled, isTrue);
        expect(states, isNotEmpty);
        expect(states.last.isBluetoothEnabled, isTrue);
        await subscription.cancel();
      });
    });

    group('Connection State Management', () {
      test('resetConnectionError clears connection error state', () {
        bleBloc.resetConnectionError();
        expect(bleBloc.state.connectionError, isFalse);
      });
    });

    group('Error Handling', () {
      test('resetConnectionError emits state transition', () async {
        final states = <BleState>[];
        final subscription = bleBloc.stream.listen(states.add);

        bleBloc.resetConnectionError();
        await Future<void>.delayed(Duration.zero);

        expect(states, isNotEmpty);
        expect(states.last.connectionError, isFalse);
        await subscription.cancel();
      });

      test('connectionError can be reset', () {
        bleBloc.resetConnectionError();
        expect(bleBloc.state.connectionError, isFalse);
      });

      test(
          'when initial BLE connection is started, if exception is thrown, reconnection continues seamlessly',
          () async {
        expect(bleBloc.state.connectionError, isFalse);
        expect(bleBloc.state.isConnecting, isFalse);
        expect(bleBloc.state.selectedDevice, isNull);

        final mockDevice = MockBluetoothDevice();
        when(() => mockDevice.connect())
            .thenThrow(Exception('Connection failed'));

        final mockContext = FakeBuildContext();

        await bleBloc.connectToDevice(mockDevice, mockContext);

        expect(bleBloc.state.connectionError, isFalse);
        expect(bleBloc.state.isConnecting, isFalse);
        expect(bleBloc.state.selectedDevice, isNull);
        expect(bleBloc.isConnected, isFalse);
      });
    });

    group('Device Management', () {
      test('devicesListStream provides stream of device lists', () {
        expect(bleBloc.devicesListStream, isA<Stream<List<dynamic>>>());
      });

      test('scanForNewDevices clears selected device', () {
        final mockDevice = MockBluetoothDevice();
        bleBloc.selectedDevice = mockDevice;

        bleBloc.scanForNewDevices();

        expect(bleBloc.selectedDevice, isNull);
        expect(bleBloc.state.selectedDevice, isNull);
      });
    });
  });
}

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

class FakeBuildContext extends Fake implements BuildContext {}
