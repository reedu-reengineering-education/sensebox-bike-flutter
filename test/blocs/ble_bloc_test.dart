import 'dart:async';

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

    group('MockBleBloc smoke', () {
      setUp(() {
        bleBloc = MockBleBloc();
      });

      tearDown(() {
        bleBloc.dispose();
      });

      test('exposes idle defaults and disconnect resets phase', () {
        expect(bleBloc.connectionPhaseNotifier.value, BleConnectionPhase.idle);
        expect(bleBloc.discoveredDevicesNotifier.value, isEmpty);
        expect(bleBloc.isConnected, isFalse);

        bleBloc.connectionPhaseNotifier.value = BleConnectionPhase.connected;
        expect(bleBloc.isConnected, isTrue);

        bleBloc.disconnectDevice();
        expect(bleBloc.connectionPhaseNotifier.value, BleConnectionPhase.idle);
        expect(bleBloc.isConnected, isFalse);
      });
    });

    group('BleBloc instance', () {
      late FakeFlutterBluePlusPlatform fakePlatform;

      setUp(() async {
        fakePlatform = FakeFlutterBluePlusPlatform();
        installFakeFlutterBluePlusPlatform(fakePlatform);
        mockSettingsBloc = MockSettingsBloc();
        bleBloc = BleBloc(mockSettingsBloc);
        await waitForBleBlocInit(bleBloc);
      });

      tearDown(() {
        bleBloc.dispose();
        fakePlatform.dispose();
      });

      test('connectToDevice transitions to connected on success', () async {
        final device = BluetoothDevice.fromId('00:11:22:33:44:55');

        final result = await bleBloc.connectToDevice(device);

        expect(result.success, isTrue, reason: '${result.failureReason}');
        expect(bleBloc.connectionPhaseNotifier.value,
            BleConnectionPhase.connected);
        expect(bleBloc.selectedDeviceNotifier.value, isNotNull);
        expect(bleBloc.isConnected, isTrue);
        expect(bleBloc.availableCharacteristics.value, isNotEmpty);
        expect(bleBloc.isReadyForRecording, isTrue);
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
    });

    group('BleBloc connect failures', () {
      late FakeFlutterBluePlusPlatform fakePlatform;

      setUp(() async {
        fakePlatform = FakeFlutterBluePlusPlatform(connectSucceeds: false);
        installFakeFlutterBluePlusPlatform(fakePlatform);
        mockSettingsBloc = MockSettingsBloc();
        bleBloc = BleBloc(mockSettingsBloc);
        await waitForBleBlocInit(bleBloc);
      });

      tearDown(() {
        bleBloc.dispose();
        fakePlatform.dispose();
      });

      test('connectToDevice returns failure when platform connect fails',
          () async {
        final device = BluetoothDevice.fromId('00:11:22:33:44:66');

        final result = await bleBloc.connectToDevice(device);

        expect(result.success, isFalse);
        expect(bleBloc.connectionPhaseNotifier.value, BleConnectionPhase.idle);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
      });
    });
  });
}

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

Future<void> waitForBleBlocInit(BleBloc bloc) async {
  if (bloc.isBluetoothEnabledNotifier.value) {
    return;
  }

  final completer = Completer<void>();
  void listener() {
    if (bloc.isBluetoothEnabledNotifier.value && !completer.isCompleted) {
      completer.complete();
    }
  }

  bloc.isBluetoothEnabledNotifier.addListener(listener);
  listener();

  await completer.future.timeout(
    const Duration(seconds: 1),
    onTimeout: () => fail('BleBloc initialization did not complete'),
  );

  bloc.isBluetoothEnabledNotifier.removeListener(listener);
}
