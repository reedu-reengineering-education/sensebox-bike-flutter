import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import '../mocks.dart';
import '../ble/mock_ble_platform.dart';

void main() {
  group('BleBloc', () {
    late BleBloc bleBloc;
    late MockSettingsBloc mockSettingsBloc;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerFallbackValue(const BleDevice(id: 'fallback', name: 'fallback'));
      registerFallbackValue(FakeBuildContext());
      registerFallbackValue(const Duration(seconds: 10));
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

      test('user-initiated disconnect calls disconnect on platform',
          () async {
        final platform = MockBlePlatform();
        when(() => platform.disconnect(any())).thenAnswer((_) async {});
        when(() => platform.dispose()).thenAnswer((_) async {});

        final realBleBloc = BleBloc(
          mockSettingsBloc,
          initializePlatformBle: false,
          platform: platform,
        );
        addTearDown(realBleBloc.dispose);

        const device = BleDevice(id: 'AA:BB:CC:DD:EE:01', name: 'senseBox:test');
        realBleBloc.selectedDevice = device;
        realBleBloc.selectedDeviceNotifier.value = device;

        await realBleBloc.disconnectDevice(
            reason: BleDisconnectReason.userRequested);

        verify(() => platform.disconnect(device.id)).called(greaterThanOrEqualTo(1));
        expect(realBleBloc.selectedDevice, isNull);
        expect(realBleBloc.selectedDeviceNotifier.value, isNull);
      });

      test('linkOnly disconnect keeps selected device and reconnecting state',
          () async {
        final platform = MockBlePlatform();
        when(() => platform.disconnect(any())).thenAnswer((_) async {});
        when(() => platform.dispose()).thenAnswer((_) async {});

        final realBleBloc = BleBloc(
          mockSettingsBloc,
          initializePlatformBle: false,
          platform: platform,
        );
        addTearDown(realBleBloc.dispose);

        const device = BleDevice(id: 'AA:BB:CC:DD:EE:01', name: 'senseBox:test');
        realBleBloc.selectedDevice = device;
        realBleBloc.selectedDeviceNotifier.value = device;
        realBleBloc.isReconnectingNotifier.value = true;

        await realBleBloc.disconnectDevice(
            device: device, reason: BleDisconnectReason.retryRelease);

        expect(realBleBloc.selectedDevice, device);
        expect(realBleBloc.selectedDeviceNotifier.value, device);
        expect(realBleBloc.isReconnectingNotifier.value, isTrue);
      });

      test('shows connection error when platform.connect throws on initial connect',
          () async {
        final platform = MockBlePlatform();
        when(() => platform.disconnect(any())).thenAnswer((_) async {});
        when(() => platform.dispose()).thenAnswer((_) async {});
        when(() => platform.connect(any(), timeout: any(named: 'timeout')))
            .thenThrow(Exception('Connection failed'));
        when(() => platform.dispose()).thenAnswer((_) async {});

        final realBleBloc = BleBloc(
          mockSettingsBloc,
          initializePlatformBle: false,
          platform: platform,
        );
        addTearDown(realBleBloc.dispose);

        const device = BleDevice(id: 'AA:BB:CC:DD:EE:02', name: 'senseBox:test');

        await realBleBloc.connectToDevice(device, FakeBuildContext());

        verify(() => platform.disconnect(device.id)).called(greaterThanOrEqualTo(1));
        expect(realBleBloc.connectionErrorNotifier.value, isTrue);
        expect(realBleBloc.isConnectingNotifier.value, isFalse);
        expect(realBleBloc.selectedDeviceNotifier.value, isNull);
        expect(realBleBloc.isConnected, isFalse);
      });
    });

    group('Device Management', () {
      test('devicesListStream provides stream of device lists', () {
        expect(bleBloc.devicesListStream, isA<Stream<List<BleDevice>>>());
      });

      test('scanForNewDevices clears selected device', () {
        const device = BleDevice(id: 'AA:BB:CC:DD:EE:01', name: 'senseBox:test');
        bleBloc.selectedDevice = device;
        bleBloc.selectedDeviceNotifier.value = device;

        bleBloc.scanForNewDevices();

        expect(bleBloc.selectedDevice, isNull);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
      });
    });
  });
}

class FakeBuildContext extends Fake implements BuildContext {}
