import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';

class _MockReactiveBle extends Mock implements FlutterReactiveBle {}

class _MockService extends Mock implements Service {}

class _MockCharacteristic extends Mock implements Characteristic {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isBluetoothAdapterEnabled', () {
    test('returns true for ready state', () {
      expect(isBluetoothAdapterEnabled(BleAdapterState.ready), isTrue);
    });

    test('returns false for poweredOff state', () {
      expect(isBluetoothAdapterEnabled(BleAdapterState.poweredOff), isFalse);
    });

    test('returns false for unknown state', () {
      expect(isBluetoothAdapterEnabled(BleAdapterState.unknown), isFalse);
    });
  });

  const deviceId = 'AA:BB:CC:DD:EE:01';

  group('BlePlatform', () {
    late BlePlatform platform;
    late _MockReactiveBle reactiveBle;

    setUp(() {
      reactiveBle = _MockReactiveBle();
      when(() => reactiveBle.statusStream)
          .thenAnswer((_) => const Stream.empty());
      platform = BlePlatform(reactiveBle: reactiveBle);
    });

    tearDown(() async {
      await platform.dispose();
    });

    test('connectionState exposes a broadcast stream per device', () {
      final stream = platform.connectionState(deviceId);
      expect(stream.isBroadcast, isTrue);
      expect(platform.connectionState(deviceId), isNotNull);
    });

    test('scanForDevices maps discovered devices', () async {
      when(() => reactiveBle.scanForDevices(
            withServices: any(named: 'withServices'),
            scanMode: ScanMode.lowLatency,
          )).thenAnswer((_) => Stream.value(DiscoveredDevice(
            id: deviceId,
            name: 'senseBox:bike',
            serviceData: const {},
            manufacturerData: Uint8List(0),
            rssi: -60,
            serviceUuids: [Uuid.parse(senseBoxServiceUuid.value)],
          )));

      final devices = await platform.scanForDevices().toList();

      expect(devices.single.id, deviceId);
      expect(devices.single.name, 'senseBox:bike');
      expect(devices.single.serviceUuids, [senseBoxServiceUuid]);
    });

    test('isConnected is false before connecting', () {
      expect(platform.isConnected(deviceId), isFalse);
    });

    test('subscribeToCharacteristic errors when characteristic is unknown',
        () async {
      final ref = BleCharacteristicRef(
        deviceId: deviceId,
        serviceUuid: senseBoxServiceUuid,
        characteristicUuid: BleUuid('11111111-2222-3333-4444-555555555555'),
      );

      await expectLater(
        platform.subscribeToCharacteristic(ref),
        emitsError(isA<StateError>()),
      );
    });

    test('watchdog drops the connection when data stops arriving', () async {
      registerFallbackValue(QualifiedCharacteristic(
        characteristicId: Uuid.parse(senseBoxServiceUuid.value),
        serviceId: Uuid.parse(senseBoxServiceUuid.value),
        deviceId: deviceId,
      ));
      platform = BlePlatform(
        reactiveBle: reactiveBle,
        dataStaleTimeout: const Duration(milliseconds: 50),
      );
      final connection = StreamController<ConnectionStateUpdate>();
      addTearDown(connection.close);
      when(() => reactiveBle.connectToDevice(
            id: deviceId,
            connectionTimeout: any(named: 'connectionTimeout'),
          )).thenAnswer((_) => connection.stream);
      final characteristicUuid = BleUuid('11111111-2222-3333-4444-555555555555');
      final characteristic = _MockCharacteristic();
      when(() => characteristic.id)
          .thenReturn(Uuid.parse(characteristicUuid.value));
      final service = _MockService();
      when(() => service.id).thenReturn(Uuid.parse(senseBoxServiceUuid.value));
      when(() => service.characteristics).thenReturn([characteristic]);
      when(() => reactiveBle.discoverAllServices(deviceId))
          .thenAnswer((_) async {});
      when(() => reactiveBle.getDiscoveredServices(deviceId))
          .thenAnswer((_) async => [service]);
      when(() => reactiveBle.subscribeToCharacteristic(any()))
          .thenAnswer((_) => Stream.value([0, 0, 0, 0]));

      final connecting = platform.connect(deviceId);
      connection.add(const ConnectionStateUpdate(
        deviceId: deviceId,
        connectionState: DeviceConnectionState.connected,
        failure: null,
      ));
      await connecting;
      await platform.discoverServices(deviceId);
      final states = <BleLinkState>[];
      platform.connectionState(deviceId).listen(states.add);

      await platform
          .subscribeToCharacteristic(BleCharacteristicRef(
            deviceId: deviceId,
            serviceUuid: senseBoxServiceUuid,
            characteristicUuid: characteristicUuid,
          ))
          .drain<void>();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(connection.hasListener, isFalse);
      expect(platform.isConnected(deviceId), isFalse);
      expect(states.last, BleLinkState.disconnected);
    });

    test('connectionState emits disconnected when connection stream closes',
        () async {
      when(
        () => reactiveBle.connectToDevice(
          id: deviceId,
          connectionTimeout: any(named: 'connectionTimeout'),
        ),
      ).thenAnswer(
        (_) => Stream<ConnectionStateUpdate>.fromIterable(
          const [
            ConnectionStateUpdate(
              deviceId: deviceId,
              connectionState: DeviceConnectionState.connected,
              failure: null,
            ),
          ],
        ),
      );

      final statesFuture = platform.connectionState(deviceId).take(3).toList();

      await platform.connect(
        deviceId,
        timeout: const Duration(seconds: 1),
      );

      final states = await statesFuture;
      expect(
        states,
        equals([
          BleLinkState.connecting,
          BleLinkState.connected,
          BleLinkState.disconnected,
        ]),
      );
    });
  });
}
