import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/models/ble_connection_phase.dart';
import '../helpers/fake_flutter_blue_plus_platform.dart';
import '../mocks.dart';

void main() {
  group('BleBloc', () {
    late BleBloc bleBloc;
    late MockSettingsBloc mockSettingsBloc;

    setUpAll(() {
      registerFallbackValue(MockBluetoothDevice());
    });

    group('MockBleBloc', () {
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
          expect(bleBloc.connectionPhaseNotifier.value,
              BleConnectionPhase.idle);
          expect(bleBloc.selectedDeviceNotifier.value, isNull);
          expect(bleBloc.discoveredDevicesNotifier.value, isEmpty);
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
        test('startScanning disconnects when a device is selected', () {
          final mockDevice = MockBluetoothDevice();
          bleBloc.selectedDeviceNotifier.value = mockDevice;

          bleBloc.startScanning();

          expect(bleBloc.selectedDeviceNotifier.value, isNull);
        });
      });
    });

    group('BleBloc instance', () {
      late FakeFlutterBluePlusPlatform fakePlatform;

      setUp(() async {
        fakePlatform = FakeFlutterBluePlusPlatform();
        installFakeFlutterBluePlusPlatform(fakePlatform);
        mockSettingsBloc = MockSettingsBloc();
        bleBloc = BleBloc(mockSettingsBloc);
        await _waitForBleBlocInit(bleBloc);
      });

      tearDown(() {
        bleBloc.dispose();
        fakePlatform.dispose();
      });

      test('starts in idle phase with empty discovered devices', () {
        expect(bleBloc.connectionPhaseNotifier.value, BleConnectionPhase.idle);
        expect(bleBloc.discoveredDevicesNotifier.value, isEmpty);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
        expect(bleBloc.isConnected, isFalse);
      });

      test('disconnectDevice clears selected device and returns to idle', () {
        final mockDevice = MockBluetoothDevice();
        when(() => mockDevice.disconnect()).thenAnswer((_) async {});

        bleBloc.selectedDeviceNotifier.value = mockDevice;
        bleBloc.disconnectDevice();

        expect(bleBloc.selectedDeviceNotifier.value, isNull);
        expect(bleBloc.connectionPhaseNotifier.value, BleConnectionPhase.idle);
        expect(bleBloc.isConnected, isFalse);
      });

      test('resetConnectionError clears permanent connection error flag', () {
        bleBloc.connectionErrorNotifier.value = true;

        bleBloc.resetConnectionError();

        expect(bleBloc.connectionErrorNotifier.value, isFalse);
      });

      test('isReadyForRecording is false without a connected device', () {
        expect(bleBloc.isReadyForRecording, isFalse);
      });

      test('startScanning populates discoveredDevicesNotifier for senseBox devices',
          () async {
        await bleBloc.startScanning();

        fakePlatform.emitScanResult(
          remoteId: '00:11:22:33:44:55',
          platformName: 'senseBox:bike',
        );
        fakePlatform.emitScanResult(
          remoteId: '00:11:22:33:44:66',
          platformName: 'OtherDevice',
        );

        await Future<void>.delayed(Duration.zero);

        expect(bleBloc.discoveredDevicesNotifier.value, hasLength(1));
        expect(
          bleBloc.discoveredDevicesNotifier.value.first.platformName,
          'senseBox:bike',
        );

        await bleBloc.stopScanning();
      });

      test('connectToDevice returns failure when platform connect fails',
          () async {
        fakePlatform.dispose();
        fakePlatform = FakeFlutterBluePlusPlatform(connectSucceeds: false);
        installFakeFlutterBluePlusPlatform(fakePlatform);

        final device = BluetoothDevice.fromId('00:11:22:33:44:55');

        final result = await bleBloc.connectToDevice(device);

        expect(result.success, isFalse);
        expect(bleBloc.connectionPhaseNotifier.value, BleConnectionPhase.idle);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
      });
    });
  });
}

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

Future<void> _waitForBleBlocInit(BleBloc bloc) async {
  for (var i = 0; i < 50; i++) {
    if (bloc.isBluetoothEnabledNotifier.value) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('BleBloc initialization did not complete');
}
