import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/services/ble/ble_client.dart';
import 'package:sensebox_bike/services/ble/connection_events.dart';
import 'package:sensebox_bike/services/ble/sensebox_connection_manager.dart';
import 'package:sensebox_bike/services/ble/sensebox_data_service.dart';
import 'package:sensebox_bike/services/ble/sensebox_device.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'fake_ble_client.dart';

void main() {
  group('SenseBoxConnectionManager', () {
    late FakeBleClient fakeBleClient;
    late SenseBoxDataService dataService;
    late SenseBoxConnectionManager manager;
    late List<ConnectionEvent> events;

    const device = SenseBoxDevice(
      id: 'device-1',
      displayName: 'senseBox:bike [abc]',
      advName: 'senseBox:bike [abc]',
    );
    const characteristic = BleCharacteristicRef(
      serviceUuid: 'CF06A218-F68E-E0BE-AD04-8EBC1EB0BC84',
      characteristicUuid: 'char-1',
    );

    setUp(() {
      fakeBleClient = FakeBleClient();
      dataService = SenseBoxDataService(fakeBleClient);
      events = [];
      manager = SenseBoxConnectionManager(
        bleClient: fakeBleClient,
        dataService: dataService,
        onConnectionEvent: events.add,
      );
      fakeBleClient.characteristicsByDevice[device.id] = [characteristic];
    });

    tearDown(() {
      manager.dispose();
      dataService.dispose();
      fakeBleClient.dispose();
    });

    test('startScanning throws ScanPermissionDenied when scan fails', () async {
      fakeBleClient.shouldThrowOnScan = true;

      expect(manager.startScanning(), throwsA(isA<ScanPermissionDenied>()));
    });

    test('connectToDevice succeeds when probe data is valid', () async {
      final payload = ByteData(4)..setFloat32(0, 12.5, Endian.little);

      final connectFuture = manager.connectToDevice(device);
      await Future<void>.delayed(Duration.zero);
      fakeBleClient.emitNotification(
        device.id,
        characteristic,
        payload.buffer.asUint8List().toList(),
      );
      await connectFuture;

      expect(manager.isConnected, isTrue);
      expect(manager.selectedDevice, isNotNull);
      expect(
        events.map((event) => event.type),
        contains(ConnectionEventType.deviceConnected),
      );
    });

    test('connectToDevice emits initialConnectionFailed when probe is invalid',
        () async {
      fakeBleClient.shouldFailDiscovery = true;

      await manager.connectToDevice(device);

      expect(manager.isConnected, isFalse);
      expect(
        events.map((event) => event.type),
        contains(ConnectionEventType.initialConnectionFailed),
      );
    });

    test('disconnectDevice skips reconnection flow', () async {
      final payload = ByteData(4)..setFloat32(0, 12.5, Endian.little);

      final connectFuture = manager.connectToDevice(device);
      await Future<void>.delayed(Duration.zero);
      fakeBleClient.emitNotification(
        device.id,
        characteristic,
        payload.buffer.asUint8List().toList(),
      );
      await connectFuture;

      manager.disconnectDevice();
      fakeBleClient.connectionStateControllers[device.id]?.add(
        BleConnectionState.disconnected,
      );
      await Future<void>.delayed(Duration.zero);

      expect(manager.isConnected, isFalse);
      expect(manager.isReconnecting, isFalse);
      expect(
        events.map((event) => event.type),
        isNot(contains(ConnectionEventType.reconnectionStarted)),
      );
    });
  });
}
