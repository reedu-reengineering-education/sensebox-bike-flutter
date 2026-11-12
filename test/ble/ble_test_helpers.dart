import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'mock_ble_platform.dart';

const testDeviceId = 'AA:BB:CC:DD:EE:01';
const testBleDevice = BleDevice(id: testDeviceId, name: 'senseBox:test');
final testCharacteristic = BleUuid('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');

void registerBleFallbackValues() {
  registerFallbackValue(testBleDevice);
  registerFallbackValue(testCharacteristic);
  registerFallbackValue(<BleUuid>[]);
  registerFallbackValue(Duration.zero);
}

Uint8List float32Bytes(List<double> values) {
  final byteData = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    byteData.setFloat32(i * 4, values[i], Endian.little);
  }
  return byteData.buffer.asUint8List();
}

void stubScan(MockBlePlatform platform, Stream<BleDevice> Function() scan) {
  when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
      .thenAnswer((_) => scan());
}

class BleTestHarness {
  BleTestHarness(SettingsBloc settingsBloc) {
    when(() => settingsBloc.vibrateOnDisconnect).thenReturn(false);
    when(() => platform.statusStream).thenAnswer((_) => adapterStates.stream);
    when(() => platform.linkStates).thenAnswer((_) => linkStates.stream);
    when(() => platform.isConnected).thenReturn(false);
    when(() => platform.disconnect()).thenAnswer((_) async {});
    when(() => platform.dispose()).thenAnswer((_) async {});
    bloc = BleBloc(
      settingsBloc,
      platform: platform,
      connectTimeLimit: Duration.zero,
      reconnectTimeLimit: Duration.zero,
    );
  }

  final platform = MockBlePlatform();
  final adapterStates = StreamController<BleAdapterState>.broadcast();
  final linkStates = StreamController<BleLinkState>.broadcast();
  late final BleBloc bloc;

  void stubConnectFailure(Object error) {
    stubScan(platform, () => Stream.value(testBleDevice));
    when(() => platform.connect(any(), timeout: any(named: 'timeout')))
        .thenThrow(error);
  }

  void stubConnectSuccess() {
    stubScan(platform, () => Stream.value(testBleDevice));
    when(() => platform.connect(any(), timeout: any(named: 'timeout')))
        .thenAnswer((_) async {
      when(() => platform.isConnected).thenReturn(true);
    });
    when(() => platform.discoverCharacteristics())
        .thenAnswer((_) async => [testCharacteristic]);
    when(() => platform.subscribeToCharacteristic(any()))
        .thenAnswer((_) => Stream.value(float32Bytes([1.0])));
  }

  Future<void> connect() async {
    bloc.updateBluetoothStatus(true);
    stubConnectSuccess();
    await bloc.connectToDevice(testBleDevice);
    expect(bloc.isConnected, isTrue);
  }

  Future<void> linkDrops() async {
    when(() => platform.isConnected).thenReturn(false);
    linkStates.add(BleLinkState.disconnected);
    await pumpEventQueue();
  }

  Future<void> dispose() async {
    if (bloc.phase != BleConnectionPhase.idle) {
      await bloc.disconnectDevice();
    }
    bloc.dispose();
    await adapterStates.close();
    await linkStates.close();
  }
}
