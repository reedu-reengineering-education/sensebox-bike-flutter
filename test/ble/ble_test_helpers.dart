import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'mock_ble_platform.dart';

const testDeviceId = 'AA:BB:CC:DD:EE:01';
const testBleDevice = BleDevice(id: testDeviceId, name: 'senseBox:test');

Uint8List float32Bytes(List<double> values) {
  final byteData = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    byteData.setFloat32(i * 4, values[i], Endian.little);
  }
  return byteData.buffer.asUint8List();
}

BleService discoveredSenseBoxService({
  required List<BleUuid> characteristics,
}) {
  return BleService(
    serviceId: senseBoxServiceUuid,
    characteristics: characteristics,
  );
}

BleCharacteristicRef testCharacteristicRef(
  String uuid, {
  String deviceId = testDeviceId,
}) {
  return BleCharacteristicRef(
    deviceId: deviceId,
    serviceUuid: senseBoxServiceUuid,
    characteristicUuid: BleUuid(uuid),
  );
}

void stubBlePlatformLifecycle(MockBlePlatform platform) {
  when(() => platform.disconnect(any())).thenAnswer((_) async {});
  when(() => platform.dispose()).thenAnswer((_) async {});
}

BleBloc createTestBleBloc(
  SettingsBloc settingsBloc, {
  MockBlePlatform? platform,
  Duration adapterOffDebounce = Duration.zero,
}) {
  final blePlatform = platform ?? MockBlePlatform();
  stubBlePlatformLifecycle(blePlatform);
  return BleBloc(
    settingsBloc,
    initializePlatformBle: false,
    platform: blePlatform,
    adapterOffDebounce: adapterOffDebounce,
    connectTimeLimit: Duration.zero,
    reconnectTimeLimit: Duration.zero,
  );
}

void primeConnectedAndWatchingLink(
  BleBloc bleBloc, {
  bool bluetoothEnabled = false,
}) {
  bleBloc.selectedDevice = testBleDevice;
  if (bluetoothEnabled) {
    bleBloc.isBluetoothEnabledNotifier.value = true;
  }
  bleBloc.debugSetConnectionPhase(BleConnectionPhase.connected);
  bleBloc.debugWatchLink(testBleDevice);
}
