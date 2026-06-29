import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import '../ble/ble_test_helpers.dart';
import '../ble/mock_ble_platform.dart';
import '../mocks.dart';

void main() {
  group('BleBloc', () {
    late MockSettingsBloc mockSettingsBloc;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerFallbackValue(const BleDevice(id: 'fallback', name: 'fallback'));
      registerFallbackValue(FakeBuildContext());
      registerFallbackValue(const Duration(seconds: 10));
    });

    setUp(() {
      mockSettingsBloc = MockSettingsBloc();
    });

    group('Initialization', () {
      test('initializes with correct default values', () {
        final bleBloc = createTestBleBloc(mockSettingsBloc);
        addTearDown(bleBloc.dispose);

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
        final bleBloc = createTestBleBloc(mockSettingsBloc);
        addTearDown(bleBloc.dispose);

        var listenerCalled = false;
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
        final bleBloc = createTestBleBloc(mockSettingsBloc);
        addTearDown(bleBloc.dispose);

        bleBloc.connectionErrorNotifier.value = true;
        bleBloc.resetConnectionError();
        expect(bleBloc.connectionErrorNotifier.value, isFalse);
      });
    });

    group('Error Handling', () {
      test('user-initiated disconnect calls disconnect on platform',
          () async {
        final platform = MockBlePlatform();
        final realBleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(realBleBloc.dispose);

        realBleBloc.selectedDevice = testBleDevice;
        realBleBloc.selectedDeviceNotifier.value = testBleDevice;

        await realBleBloc.disconnectDevice(
            reason: BleDisconnectReason.userRequested);

        verify(() => platform.disconnect(testBleDevice.id))
            .called(greaterThanOrEqualTo(1));
        expect(realBleBloc.selectedDevice, isNull);
        expect(realBleBloc.selectedDeviceNotifier.value, isNull);
      });

      test('linkOnly disconnect keeps selected device and reconnecting state',
          () async {
        final platform = MockBlePlatform();
        final realBleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(realBleBloc.dispose);

        realBleBloc.selectedDevice = testBleDevice;
        realBleBloc.selectedDeviceNotifier.value = testBleDevice;
        realBleBloc.isReconnectingNotifier.value = true;

        await realBleBloc.disconnectDevice(
            device: testBleDevice, reason: BleDisconnectReason.retryRelease);

        expect(realBleBloc.selectedDevice, testBleDevice);
        expect(realBleBloc.selectedDeviceNotifier.value, testBleDevice);
        expect(realBleBloc.isReconnectingNotifier.value, isTrue);
      });

      test('shows connection error when platform.connect throws on initial connect',
          () async {
        final platform = MockBlePlatform();
        stubBlePlatformLifecycle(platform);
        const device = BleDevice(id: 'AA:BB:CC:DD:EE:02', name: 'senseBox:test');
        when(() => platform.scanForDevices())
            .thenAnswer((_) => Stream.value(device));
        when(() => platform.isConnected(any())).thenReturn(false);
        when(() => platform.connect(any(), timeout: any(named: 'timeout')))
            .thenThrow(Exception('Connection failed'));

        final realBleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(realBleBloc.dispose);
        realBleBloc.updateBluetoothStatus(true);

        await realBleBloc.connectToDevice(device, FakeBuildContext());

        verify(() => platform.disconnect(device.id)).called(greaterThanOrEqualTo(1));
        expect(realBleBloc.connectionErrorNotifier.value, isTrue);
        expect(realBleBloc.isConnectingNotifier.value, isFalse);
        expect(realBleBloc.selectedDeviceNotifier.value, isNull);
        expect(realBleBloc.isConnected, isFalse);
      });
    });

    group('Adapter power cycle', () {
      late MockBlePlatform platform;
      late BleBloc realBleBloc;

      setUp(() {
        platform = MockBlePlatform();
        stubBlePlatformLifecycle(platform);
        when(() => mockSettingsBloc.vibrateOnDisconnect).thenReturn(false);
        when(() => platform.isConnected(any())).thenAnswer((_) => true);
        when(() => platform.connectionState(any()))
            .thenAnswer((_) => const Stream.empty());

        realBleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
      });

      tearDown(() {
        realBleBloc.dispose();
      });

      test('powered off tears down platform link when link is gone', () async {
        realBleBloc.selectedDevice = testBleDevice;
        realBleBloc.debugSetConnectionPhase(BleConnectionPhase.connected);
        // Link did not survive the adapter-off blip.
        when(() => platform.isConnected(testBleDevice.id)).thenReturn(false);

        await realBleBloc.debugOnBluetoothPoweredOff();

        verify(() => platform.disconnect(testBleDevice.id)).called(1);
      });

      test('powered off ignores transient blip when link survives debounce',
          () async {
        primeConnectedWithReconnectionListener(
          realBleBloc,
          bluetoothEnabled: true,
        );
        // isConnected stays true (stubbed in setUp): the link survived the blip.

        await realBleBloc.debugOnBluetoothPoweredOff();

        verifyNever(() => platform.disconnect(testBleDevice.id));
        expect(realBleBloc.isReconnectingNotifier.value, isFalse);
        expect(realBleBloc.isConnected, isTrue);
      });

      test('powered off starts reconnecting when listener is attached',
          () async {
        primeConnectedWithReconnectionListener(
          realBleBloc,
          bluetoothEnabled: true,
        );
        // Link is gone after the adapter-off blip.
        when(() => platform.isConnected(testBleDevice.id)).thenReturn(false);
        when(() => platform.scanForDevices())
            .thenAnswer((_) => const Stream.empty());
        when(() => platform.connect(any(), timeout: any(named: 'timeout')))
            .thenAnswer((_) async {});

        unawaited(realBleBloc.debugOnBluetoothPoweredOff());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(realBleBloc.isReconnectingNotifier.value, isTrue);

        await realBleBloc.disconnectDevice(
          reason: BleDisconnectReason.userRequested,
        );
      });

      test('powered on reconnects when platform still reports connected after adapter off',
          () async {
        primeConnectedWithReconnectionListener(
          realBleBloc,
          bluetoothEnabled: true,
        );
        realBleBloc.debugMarkLinkLostDueToAdapterPowerOff();
        when(() => platform.isConnected(testBleDevice.id)).thenReturn(true);
        when(() => platform.connect(any(), timeout: any(named: 'timeout')))
            .thenAnswer((_) async {});

        unawaited(realBleBloc.debugOnBluetoothPoweredOn());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(realBleBloc.isReconnectingNotifier.value, isTrue);

        await realBleBloc.disconnectDevice(
          reason: BleDisconnectReason.userRequested,
        );
      });

      test('powered on skips reconnect when link is live and adapter was not powered off',
          () async {
        primeConnectedWithReconnectionListener(realBleBloc);
        when(() => platform.isConnected(testBleDevice.id)).thenReturn(true);

        await realBleBloc.debugOnBluetoothPoweredOn();

        expect(realBleBloc.isReconnectingNotifier.value, isFalse);
        verifyNever(() => platform.disconnect(testBleDevice.id));
      });
    });

    group('Device Management', () {
      test('scanForNewDevices clears selected device', () async {
        final bleBloc = MockBleBloc();
        addTearDown(bleBloc.dispose);

        bleBloc.selectedDevice = testBleDevice;
        bleBloc.selectedDeviceNotifier.value = testBleDevice;

        await bleBloc.scanForNewDevices();

        expect(bleBloc.selectedDevice, isNull);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
      });

      test('scanForNewDevices awaits disconnect before starting scan', () async {
        final platform = MockBlePlatform();
        var scanCalled = false;

        when(() => platform.disconnect(any())).thenAnswer((_) async {
          expect(scanCalled, isFalse);
        });
        when(() => platform.scanForDevices()).thenAnswer((_) {
          scanCalled = true;
          return const Stream<BleDevice>.empty();
        });

        final bleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(bleBloc.dispose);

        bleBloc.selectedDevice = testBleDevice;
        bleBloc.selectedDeviceNotifier.value = testBleDevice;

        await bleBloc.scanForNewDevices();

        expect(scanCalled, isTrue);
        verify(() => platform.disconnect(testBleDevice.id)).called(1);
      });
    });
  });
}

class FakeBuildContext extends Fake implements BuildContext {}
