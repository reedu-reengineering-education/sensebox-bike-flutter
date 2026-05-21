import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/services/ble/sensebox_device.dart';
import '../mocks.dart';

void main() {
  group('BleBloc', () {
    late BleBloc bleBloc;
    late MockSettingsBloc mockSettingsBloc;

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
      });
    });

    group('Bluetooth Status', () {
      test('updateBluetoothStatus updates notifier and notifies listeners', () {
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
        bleBloc.connectionErrorNotifier.value = true;
        bleBloc.resetConnectionError();
        expect(bleBloc.connectionErrorNotifier.value, isFalse);
      });
    });

    group('Device Management', () {
      test('devicesListStream provides stream of device lists', () {
        expect(bleBloc.devicesListStream, isA<Stream<List<SenseBoxDevice>>>());
      });

      test('scanForNewDevices clears selected device', () {
        const mockDevice = SenseBoxDevice(
          id: 'device-1',
          displayName: 'senseBox:bike [abc]',
        );
        bleBloc.selectedDevice = mockDevice;
        bleBloc.selectedDeviceNotifier.value = mockDevice;

        bleBloc.scanForNewDevices();

        expect(bleBloc.selectedDevice, isNull);
        expect(bleBloc.selectedDeviceNotifier.value, isNull);
      });
    });
  });
}
