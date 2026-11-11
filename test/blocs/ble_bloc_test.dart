import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../ble/ble_test_helpers.dart';
import '../ble/mock_ble_platform.dart';
import '../mocks.dart';

void main() {
  group('BleBloc', () {
    late MockSettingsBloc mockSettingsBloc;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerFallbackValue(const BleDevice(id: 'fallback', name: 'fallback'));
      registerFallbackValue(const Duration(seconds: 10));
      registerFallbackValue(<BleUuid>[]);
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
        when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
            .thenAnswer((_) => Stream.value(device));
        when(() => platform.isConnected(any())).thenReturn(false);
        when(() => platform.connect(any(), timeout: any(named: 'timeout')))
            .thenThrow(Exception('Connection failed'));

        final realBleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(realBleBloc.dispose);
        realBleBloc.updateBluetoothStatus(true);

        await realBleBloc.connectToDevice(device);

        verify(() => platform.disconnect(device.id)).called(greaterThanOrEqualTo(1));
        expect(realBleBloc.connectionErrorNotifier.value, isTrue);
        expect(realBleBloc.isConnectingNotifier.value, isFalse);
        expect(realBleBloc.selectedDeviceNotifier.value, isNull);
        expect(realBleBloc.isConnected, isFalse);
      });

      test('reports a failed initial connect once, with the connect error',
          () async {
        final reported = await _captureSentryEvents();

        final platform = MockBlePlatform();
        stubBlePlatformLifecycle(platform);
        const device = BleDevice(id: 'AA:BB:CC:DD:EE:02', name: 'senseBox:test');
        when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
            .thenAnswer((_) => Stream.value(device));
        when(() => platform.isConnected(any())).thenReturn(false);
        when(() => platform.connect(any(), timeout: any(named: 'timeout')))
            .thenThrow(Exception('Connection failed'));

        final realBleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(realBleBloc.dispose);
        realBleBloc.updateBluetoothStatus(true);

        await realBleBloc.connectToDevice(device);

        expect(reported, hasLength(1));
        final failure = reported.single as BleConnectionFailed;
        expect(failure.phase, BleConnectionFailurePhase.initialConnect);
        expect(failure.cause.toString(), contains('Connection failed'));
      });

      test('reports a scan error as the connect failure cause', () async {
        final reported = await _captureSentryEvents();

        final platform = MockBlePlatform();
        stubBlePlatformLifecycle(platform);
        const device = BleDevice(id: 'AA:BB:CC:DD:EE:04', name: 'senseBox:test');
        final scanError = Exception('Bluetooth disabled');
        when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
            .thenAnswer((_) => Stream.error(scanError, StackTrace.empty));
        when(() => platform.isConnected(any())).thenReturn(false);

        final realBleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(realBleBloc.dispose);
        realBleBloc.updateBluetoothStatus(true);

        await realBleBloc.connectToDevice(device);

        expect(reported, hasLength(1));
        final failure = reported.single as BleConnectionFailed;
        expect(failure.cause, same(scanError));
      });

      test('reports a failed reconnect once, with the last error as cause',
          () async {
        final reported = await _captureSentryEvents();

        final platform = MockBlePlatform();
        stubBlePlatformLifecycle(platform);
        const device = BleDevice(id: 'AA:BB:CC:DD:EE:03', name: 'senseBox:test');
        final linkStates = StreamController<BleLinkState>.broadcast();
        addTearDown(linkStates.close);
        when(() => platform.connectionState(device.id))
            .thenAnswer((_) => linkStates.stream);
        when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
            .thenAnswer((_) => Stream.value(device));
        when(() => platform.isConnected(any())).thenReturn(false);
        when(() => platform.connect(any(), timeout: any(named: 'timeout')))
            .thenThrow(Exception('Reconnect failed'));
        when(() => mockSettingsBloc.vibrateOnDisconnect).thenReturn(false);

        final realBleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(realBleBloc.dispose);
        realBleBloc.updateBluetoothStatus(true);
        realBleBloc.selectedDevice = device;
        realBleBloc.debugSetConnectionPhase(BleConnectionPhase.connected);
        realBleBloc.debugWatchLink(device);

        linkStates.add(BleLinkState.disconnected);
        while (realBleBloc.selectedDevice != null) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        expect(reported, hasLength(1));
        final failure = reported.single as BleConnectionFailed;
        expect(failure.phase, BleConnectionFailurePhase.reconnection);
        expect(failure.cause.toString(), contains('Reconnect failed'));
        expect(realBleBloc.connectionErrorNotifier.value, isTrue);
      });

      test('user disconnect during a reconnect stops it without reporting',
          () async {
        final reported = await _captureSentryEvents();

        final platform = MockBlePlatform();
        stubBlePlatformLifecycle(platform);
        const device = BleDevice(id: 'AA:BB:CC:DD:EE:05', name: 'senseBox:test');
        final linkStates = StreamController<BleLinkState>.broadcast();
        addTearDown(linkStates.close);
        final pendingConnect = Completer<void>();
        when(() => platform.connectionState(device.id))
            .thenAnswer((_) => linkStates.stream);
        when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
            .thenAnswer((_) => Stream.value(device));
        when(() => platform.isConnected(any())).thenReturn(false);
        when(() => platform.connect(any(), timeout: any(named: 'timeout')))
            .thenAnswer((_) => pendingConnect.future);
        when(() => mockSettingsBloc.vibrateOnDisconnect).thenReturn(false);

        final realBleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(realBleBloc.dispose);
        realBleBloc.updateBluetoothStatus(true);
        realBleBloc.selectedDevice = device;
        realBleBloc.debugSetConnectionPhase(BleConnectionPhase.connected);
        realBleBloc.debugWatchLink(device);

        linkStates.add(BleLinkState.disconnected);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(realBleBloc.isReconnectingNotifier.value, isTrue);

        await realBleBloc.disconnectDevice(
          reason: BleDisconnectReason.userRequested,
        );
        when(() => platform.isConnected(any())).thenReturn(true);
        pendingConnect.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(reported, isEmpty);
        expect(realBleBloc.isConnected, isFalse);
        expect(realBleBloc.selectedDevice, isNull);
        verify(() => platform.disconnect(device.id)).called(greaterThanOrEqualTo(2));
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
        primeConnectedAndWatchingLink(
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
        primeConnectedAndWatchingLink(
          realBleBloc,
          bluetoothEnabled: true,
        );
        // Link is gone after the adapter-off blip.
        when(() => platform.isConnected(testBleDevice.id)).thenReturn(false);
        when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
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

      test('powered on reconnects when the link is down', () async {
        primeConnectedAndWatchingLink(
          realBleBloc,
          bluetoothEnabled: true,
        );
        when(() => platform.isConnected(testBleDevice.id)).thenReturn(false);
        final scan = StreamController<BleDevice>();
        addTearDown(scan.close);
        when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
            .thenAnswer((_) => scan.stream);

        unawaited(realBleBloc.debugOnBluetoothPoweredOn());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(realBleBloc.isReconnectingNotifier.value, isTrue);
        verify(() => platform.scanForDevices(withServices: any(named: 'withServices')))
            .called(1);

        await realBleBloc.disconnectDevice(
          reason: BleDisconnectReason.userRequested,
        );
      });

      test('powered on skips reconnect when the link is live',
          () async {
        primeConnectedAndWatchingLink(realBleBloc);
        when(() => platform.isConnected(testBleDevice.id)).thenReturn(true);

        await realBleBloc.debugOnBluetoothPoweredOn();

        expect(realBleBloc.isReconnectingNotifier.value, isFalse);
        verifyNever(() => platform.disconnect(testBleDevice.id));
      });
    });

    group('Disconnect vibration', () {
      late MockBlePlatform platform;
      late BleBloc realBleBloc;
      late void Function(String, BleLinkState?, BleLinkState) linkChanged;

      setUp(() {
        platform = MockBlePlatform();
        when(() => mockSettingsBloc.vibrateOnDisconnect).thenReturn(false);
        when(() => platform.isConnected(any())).thenReturn(true);
        when(() => platform.connectionState(any()))
            .thenAnswer((_) => const Stream.empty());
        realBleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        linkChanged = verify(() => platform.onLinkStateChanged = captureAny())
            .captured
            .single as void Function(String, BleLinkState?, BleLinkState);
        primeConnectedAndWatchingLink(realBleBloc);
      });

      tearDown(() => realBleBloc.dispose());

      test('considers vibrating when a connected box drops', () {
        linkChanged(
            testBleDevice.id, BleLinkState.connected, BleLinkState.disconnected);

        verify(() => mockSettingsBloc.vibrateOnDisconnect).called(1);
      });

      test('does not vibrate when the user disconnects', () async {
        await realBleBloc.disconnectDevice(
          reason: BleDisconnectReason.userRequested,
        );
        linkChanged(
            testBleDevice.id, BleLinkState.connected, BleLinkState.disconnected);

        verifyNever(() => mockSettingsBloc.vibrateOnDisconnect);
      });

      test('does not vibrate for links dropped while reconnecting', () {
        realBleBloc.debugSetConnectionPhase(BleConnectionPhase.reconnecting);
        linkChanged(
            testBleDevice.id, BleLinkState.connected, BleLinkState.disconnected);

        verifyNever(() => mockSettingsBloc.vibrateOnDisconnect);
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
        when(() => platform.scanForDevices(withServices: any(named: 'withServices'))).thenAnswer((_) {
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

    group('Auto-connect to remembered device', () {
      test('does nothing when no device is remembered', () async {
        final platform = MockBlePlatform();
        when(() => mockSettingsBloc.rememberedDeviceId).thenReturn(null);

        final bleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(bleBloc.dispose);
        bleBloc.updateBluetoothStatus(true);

        await bleBloc.autoConnectToRememberedDevice();

        verifyNever(() => platform.scanForDevices(withServices: any(named: 'withServices')));
      });

      test('does nothing when bluetooth is disabled', () async {
        final platform = MockBlePlatform();
        when(() => mockSettingsBloc.rememberedDeviceId)
            .thenReturn(testDeviceId);
        when(() => mockSettingsBloc.rememberedDeviceName)
            .thenReturn(testBleDevice.name);

        final bleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(bleBloc.dispose);
        // Bluetooth left disabled (default).

        await bleBloc.autoConnectToRememberedDevice();

        verifyNever(() => platform.scanForDevices(withServices: any(named: 'withServices')));
      });

      test('does nothing when a device is already selected', () async {
        final platform = MockBlePlatform();
        when(() => mockSettingsBloc.rememberedDeviceId)
            .thenReturn(testDeviceId);
        when(() => mockSettingsBloc.rememberedDeviceName)
            .thenReturn(testBleDevice.name);

        final bleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(bleBloc.dispose);
        bleBloc.updateBluetoothStatus(true);
        bleBloc.selectedDevice = testBleDevice;

        await bleBloc.autoConnectToRememberedDevice();

        verifyNever(() => platform.scanForDevices(withServices: any(named: 'withServices')));
      });

      test(
          'gives up quietly without a connection error when the device never advertises',
          () async {
        final platform = MockBlePlatform();
        when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
            .thenAnswer((_) => const Stream<BleDevice>.empty());
        when(() => mockSettingsBloc.rememberedDeviceId)
            .thenReturn(testDeviceId);
        when(() => mockSettingsBloc.rememberedDeviceName)
            .thenReturn(testBleDevice.name);

        final bleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(bleBloc.dispose);
        bleBloc.updateBluetoothStatus(true);

        await bleBloc.autoConnectToRememberedDevice(
          scanTimeout: const Duration(milliseconds: 50),
        );

        expect(bleBloc.selectedDevice, isNull);
        expect(bleBloc.connectionErrorNotifier.value, isFalse);
        expect(bleBloc.isConnectingNotifier.value, isFalse);
      });

      test('attempts to connect once the remembered device advertises',
          () async {
        final platform = MockBlePlatform();
        stubBlePlatformLifecycle(platform);
        when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
            .thenAnswer((_) => Stream.value(testBleDevice));
        when(() => platform.isConnected(any())).thenReturn(false);
        when(() => platform.connect(any(), timeout: any(named: 'timeout')))
            .thenThrow(Exception('Connection failed'));
        when(() => mockSettingsBloc.rememberedDeviceId)
            .thenReturn(testDeviceId);
        when(() => mockSettingsBloc.rememberedDeviceName)
            .thenReturn(testBleDevice.name);

        final bleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(bleBloc.dispose);
        bleBloc.updateBluetoothStatus(true);

        await bleBloc.autoConnectToRememberedDevice(
          scanTimeout: const Duration(milliseconds: 50),
        );

        // A real advertisement was found, so this is a genuine connect
        // attempt (and failure) rather than a silent "box is off" give-up.
        verify(() => platform.connect(testBleDevice.id,
            timeout: any(named: 'timeout'))).called(greaterThanOrEqualTo(1));
        expect(bleBloc.connectionErrorNotifier.value, isTrue);
      });

      test('bluetooth powering back on retries auto-connect', () async {
        final platform = MockBlePlatform();
        stubBlePlatformLifecycle(platform);
        var scanCalled = false;
        when(() => platform.scanForDevices(withServices: any(named: 'withServices'))).thenAnswer((_) {
          scanCalled = true;
          return const Stream<BleDevice>.empty();
        });
        when(() => mockSettingsBloc.rememberedDeviceId)
            .thenReturn(testDeviceId);
        when(() => mockSettingsBloc.rememberedDeviceName)
            .thenReturn(testBleDevice.name);

        final bleBloc = createTestBleBloc(mockSettingsBloc, platform: platform);
        addTearDown(bleBloc.dispose);
        bleBloc.updateBluetoothStatus(true);
        // No selected device: this is the "nothing to reconnect" branch that
        // now also kicks off a silent auto-connect attempt.

        unawaited(bleBloc.debugOnBluetoothPoweredOn());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(scanCalled, isTrue);

        await bleBloc.disconnectDevice(reason: BleDisconnectReason.userRequested);
      });
    });
  });
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
