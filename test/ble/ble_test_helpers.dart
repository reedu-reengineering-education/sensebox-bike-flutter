import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_reconnection_coordinator.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
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

class ReconnectionTestSpy {
  int linkLostCalls = 0;
  int reconnectCalls = 0;
  bool? episodeSuccess;
  Object? listenerError;

  void attach(
    BleReconnectionCoordinator coordinator,
    BleDevice device, {
    bool Function()? shouldIgnoreDisconnect,
    void Function()? onLinkLost,
    Future<bool> Function(BleDevice device)? runReconnectSessions,
    void Function()? onReconnectSucceeded,
    void Function(bool success)? onReconnectEpisodeEnded,
    Future<void> Function(BleDevice device, Object error)? onListenerError,
  }) {
    coordinator.attach(
      device,
      shouldIgnoreDisconnect: shouldIgnoreDisconnect ?? (() => false),
      onLinkLost: onLinkLost ?? () => linkLostCalls++,
      runReconnectSessions: runReconnectSessions ??
          (_) async {
            reconnectCalls++;
            return true;
          },
      onReconnectSucceeded: onReconnectSucceeded ?? () {},
      onReconnectEpisodeEnded:
          onReconnectEpisodeEnded ?? (success) => episodeSuccess = success,
      onListenerError: onListenerError ??
          (_, error) async {
            listenerError = error;
          },
    );
  }
}
