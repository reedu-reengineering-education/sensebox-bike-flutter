import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../ble/ble_test_helpers.dart';
import '../mocks.dart';

void main() {
  late MockSettingsBloc settingsBloc;
  late BleTestHarness ble;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerBleFallbackValues();
  });

  setUp(() {
    settingsBloc = MockSettingsBloc();
    ble = BleTestHarness(settingsBloc);
  });

  tearDown(() => ble.dispose());

  void rememberDevice() {
    when(() => settingsBloc.rememberedDeviceId).thenReturn(testDeviceId);
    when(() => settingsBloc.rememberedDeviceName)
        .thenReturn(testBleDevice.name);
  }

  Future<void> untilIdle() async {
    while (ble.bloc.phase != BleConnectionPhase.idle) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('starts idle, with Bluetooth off and nothing selected', () {
    expect(ble.bloc.isBluetoothEnabledNotifier.value, isFalse);
    expect(ble.bloc.phase, BleConnectionPhase.idle);
    expect(ble.bloc.selectedDevice, isNull);
    expect(ble.bloc.availableCharacteristics.value, isEmpty);
    expect(ble.bloc.connectionErrorNotifier.value, isFalse);
    expect(ble.bloc.isConnected, isFalse);
  });

  test('follows the adapter state and notifies listeners', () async {
    var notified = false;
    ble.bloc.addListener(() => notified = true);

    ble.adapterStates.add(BleAdapterState.ready);
    await pumpEventQueue();

    expect(ble.bloc.isBluetoothEnabledNotifier.value, isTrue);
    expect(notified, isTrue);
  });

  group('connect', () {
    test('connects, selects the device and publishes its characteristics',
        () async {
      await ble.connect();

      expect(ble.bloc.selectedDevice, testBleDevice);
      expect(ble.bloc.availableCharacteristics.value, [testCharacteristic]);
      expect(ble.bloc.connectionErrorNotifier.value, isFalse);
    });

    test('ignores a connect while another connection is active', () async {
      await ble.connect();

      await ble.bloc.connectToDevice(
          const BleDevice(id: 'AA:BB:CC:DD:EE:02', name: 'senseBox:other'));

      expect(ble.bloc.selectedDevice, testBleDevice);
      verify(() => ble.platform.connect(any(), timeout: any(named: 'timeout')))
          .called(1);
    });

    test('shows the connection error when the connect fails', () async {
      ble.bloc.updateBluetoothStatus(true);
      ble.stubConnectFailure(Exception('Connection failed'));

      await ble.bloc.connectToDevice(testBleDevice);

      verify(() => ble.platform.disconnect()).called(greaterThanOrEqualTo(1));
      expect(ble.bloc.connectionErrorNotifier.value, isTrue);
      expect(ble.bloc.phase, BleConnectionPhase.idle);
      expect(ble.bloc.selectedDevice, isNull);
    });

    test('reports a failed connect once, with the connect error as cause',
        () async {
      final reported = await _captureSentryEvents();
      ble.bloc.updateBluetoothStatus(true);
      ble.stubConnectFailure(Exception('Connection failed'));

      await ble.bloc.connectToDevice(testBleDevice);

      final failure = reported.single as BleConnectionFailed;
      expect(failure.phase, BleConnectionFailurePhase.initialConnect);
      expect(failure.cause.toString(), contains('Connection failed'));
    });

    test('reports a scan error as the cause', () async {
      final reported = await _captureSentryEvents();
      ble.bloc.updateBluetoothStatus(true);
      final scanError = Exception('Bluetooth disabled');
      stubScan(ble.platform, Stream.error(scanError, StackTrace.empty));

      await ble.bloc.connectToDevice(testBleDevice);

      expect((reported.single as BleConnectionFailed).cause, same(scanError));
    });

    test('connectToName scans for the box by name', () async {
      ble.bloc.updateBluetoothStatus(true);
      ble.stubConnectSuccess();

      await ble.bloc.connectToName(testBleDevice.name);

      expect(ble.bloc.selectedDevice, testBleDevice);
    });
  });

  group('disconnect', () {
    test('releases the link and clears the selection', () async {
      await ble.connect();

      await ble.bloc.disconnectDevice();

      verify(() => ble.platform.disconnect()).called(greaterThanOrEqualTo(1));
      expect(ble.bloc.selectedDevice, isNull);
      expect(ble.bloc.availableCharacteristics.value, isEmpty);
      expect(ble.bloc.phase, BleConnectionPhase.idle);
    });
  });

  group('reconnect', () {
    test('reconnects when a connected box drops', () async {
      await ble.connect();

      await ble.linkDrops();
      await untilConnected(ble.bloc);

      verify(() => ble.platform.connect(any(), timeout: any(named: 'timeout')))
          .called(2);
      expect(ble.bloc.selectedDevice, testBleDevice);
    });

    test('reports a failed reconnect once, with the last error as cause',
        () async {
      final reported = await _captureSentryEvents();
      await ble.connect();
      ble.stubConnectFailure(Exception('Reconnect failed'));

      await ble.linkDrops();
      await untilIdle();

      final failure = reported.single as BleConnectionFailed;
      expect(failure.phase, BleConnectionFailurePhase.reconnection);
      expect(failure.cause.toString(), contains('Reconnect failed'));
      expect(ble.bloc.connectionErrorNotifier.value, isTrue);
    });

    test('user disconnect during a reconnect stops it without reporting',
        () async {
      final reported = await _captureSentryEvents();
      await ble.connect();
      final pendingConnect = Completer<void>();
      when(() => ble.platform.connect(any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) => pendingConnect.future);

      await ble.linkDrops();
      expect(ble.bloc.phase, BleConnectionPhase.reconnecting);
      await ble.bloc.disconnectDevice();
      when(() => ble.platform.isConnected).thenReturn(true);
      pendingConnect.complete();
      await pumpEventQueue();

      expect(reported, isEmpty);
      expect(ble.bloc.phase, BleConnectionPhase.idle);
      expect(ble.bloc.selectedDevice, isNull);
    });

    test('waits for Bluetooth before retrying', () async {
      await ble.connect();
      ble.adapterStates.add(BleAdapterState.poweredOff);
      await pumpEventQueue();

      await ble.linkDrops();
      expect(ble.bloc.phase, BleConnectionPhase.reconnecting);
      verify(() => ble.platform.connect(any(), timeout: any(named: 'timeout')))
          .called(1);

      ble.adapterStates.add(BleAdapterState.ready);
      await untilConnected(ble.bloc);

      verify(() => ble.platform.connect(any(), timeout: any(named: 'timeout')))
          .called(1);
    });
  });

  group('vibration on disconnect', () {
    test('is considered when a connected box drops', () async {
      await ble.connect();

      await ble.linkDrops();

      verify(() => settingsBloc.vibrateOnDisconnect).called(1);
    });

    test('is skipped when the user disconnects', () async {
      await ble.connect();

      await ble.bloc.disconnectDevice();
      await ble.linkDrops();

      verifyNever(() => settingsBloc.vibrateOnDisconnect);
    });

    test('is skipped for links dropped while reconnecting', () async {
      await ble.connect();
      stubScan(ble.platform, const Stream.empty());

      await ble.linkDrops();
      await ble.linkDrops();

      expect(ble.bloc.phase, BleConnectionPhase.reconnecting);
      verify(() => settingsBloc.vibrateOnDisconnect).called(1);
    });
  });

  group('auto-connect to the remembered device', () {
    test('does nothing when no device is remembered', () async {
      ble.bloc.updateBluetoothStatus(true);

      await ble.bloc.autoConnectToRememberedDevice();

      verifyNever(() => ble.platform
          .scanForDevices(withServices: any(named: 'withServices')));
    });

    test('does nothing while Bluetooth is off', () async {
      rememberDevice();

      await ble.bloc.autoConnectToRememberedDevice();

      verifyNever(() => ble.platform
          .scanForDevices(withServices: any(named: 'withServices')));
    });

    test('does nothing while a box is connected', () async {
      rememberDevice();
      await ble.connect();

      await ble.bloc.autoConnectToRememberedDevice();

      verify(() => ble.platform
          .scanForDevices(withServices: any(named: 'withServices'))).called(1);
    });

    test('does nothing after the user disconnected', () async {
      rememberDevice();
      await ble.connect();
      await ble.bloc.disconnectDevice();

      await ble.bloc.autoConnectToRememberedDevice();

      verify(() => ble.platform
          .scanForDevices(withServices: any(named: 'withServices'))).called(1);
    });

    test('gives up quietly when the device never advertises', () async {
      rememberDevice();
      ble.bloc.updateBluetoothStatus(true);
      stubScan(ble.platform, const Stream.empty());

      await ble.bloc.autoConnectToRememberedDevice(
        scanTimeout: const Duration(milliseconds: 50),
      );

      expect(ble.bloc.selectedDevice, isNull);
      expect(ble.bloc.connectionErrorNotifier.value, isFalse);
      expect(ble.bloc.phase, BleConnectionPhase.idle);
    });

    test('connects once the remembered device advertises', () async {
      rememberDevice();
      ble.bloc.updateBluetoothStatus(true);
      ble.stubConnectSuccess();

      await ble.bloc.autoConnectToRememberedDevice();

      expect(ble.bloc.selectedDevice, testBleDevice);
    });

    test('runs when Bluetooth comes on while idle', () async {
      rememberDevice();
      stubScan(ble.platform, const Stream.empty());

      ble.adapterStates.add(BleAdapterState.ready);
      await pumpEventQueue();

      verify(() => ble.platform
          .scanForDevices(withServices: any(named: 'withServices'))).called(1);
    });
  });
}

Future<void> untilConnected(BleBloc bloc) async {
  while (!bloc.isConnected) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<List<Object?>> _captureSentryEvents() async {
  final reported = <Object?>[];
  await Sentry.init((options) {
    options.dsn = 'https://public@example.com/1';
    options.beforeSend = (event, hint) {
      reported.add(event.throwable);
      return null;
    };
  });
  addTearDown(Sentry.close);
  return reported;
}
