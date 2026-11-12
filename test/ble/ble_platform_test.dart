import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'ble_test_helpers.dart';

class _MockReactiveBle extends Mock implements FlutterReactiveBle {}

class _MockService extends Mock implements Service {}

class _MockCharacteristic extends Mock implements Characteristic {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BlePlatform platform;
  late _MockReactiveBle reactiveBle;
  late StreamController<ConnectionStateUpdate> connection;

  setUpAll(() {
    registerBleFallbackValues();
    registerFallbackValue(QualifiedCharacteristic(
      characteristicId: Uuid.parse(senseBoxServiceUuid.value),
      serviceId: Uuid.parse(senseBoxServiceUuid.value),
      deviceId: testDeviceId,
    ));
  });

  setUp(() {
    reactiveBle = _MockReactiveBle();
    connection = StreamController<ConnectionStateUpdate>();
    when(() => reactiveBle.statusStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => reactiveBle.connectToDevice(
          id: testDeviceId,
          connectionTimeout: any(named: 'connectionTimeout'),
        )).thenAnswer((_) => connection.stream);
    when(() => reactiveBle.discoverAllServices(testDeviceId))
        .thenAnswer((_) async {});
    platform = BlePlatform(
      reactiveBle: reactiveBle,
      dataStaleTimeout: const Duration(milliseconds: 50),
    );
  });

  tearDown(() async {
    await platform.dispose();
    unawaited(connection.close());
  });

  Service service(BleUuid id, List<BleUuid> characteristics) {
    final mockCharacteristics = [
      for (final uuid in characteristics) _characteristicWithId(uuid),
    ];
    final service = _MockService();
    when(() => service.id).thenReturn(Uuid.parse(id.value));
    when(() => service.characteristics).thenReturn(mockCharacteristics);
    return service;
  }

  Future<void> connect() async {
    final connecting = platform.connect(testDeviceId);
    connection.add(const ConnectionStateUpdate(
      deviceId: testDeviceId,
      connectionState: DeviceConnectionState.connected,
      failure: null,
    ));
    await connecting;
  }

  test('scanForDevices maps discovered devices', () async {
    when(() => reactiveBle.scanForDevices(
          withServices: any(named: 'withServices'),
          scanMode: ScanMode.lowLatency,
        )).thenAnswer((_) => Stream.value(DiscoveredDevice(
          id: testDeviceId,
          name: 'senseBox:bike',
          serviceData: const {},
          manufacturerData: Uint8List(0),
          rssi: -60,
          serviceUuids: [Uuid.parse(senseBoxServiceUuid.value)],
        )));

    final devices = await platform.scanForDevices().toList();

    expect(devices.single.id, testDeviceId);
    expect(devices.single.name, 'senseBox:bike');
    expect(devices.single.serviceUuids, [senseBoxServiceUuid]);
  });

  test('reports link states while connecting and after the stream closes',
      () async {
    final states = <BleLinkState>[];
    platform.linkStates.listen(states.add);

    await connect();
    expect(platform.isConnected, isTrue);

    await connection.close();
    await pumpEventQueue();

    expect(states, [
      BleLinkState.connecting,
      BleLinkState.connected,
      BleLinkState.disconnected,
    ]);
    expect(platform.isConnected, isFalse);
  });

  test('discoverCharacteristics returns the senseBox characteristics',
      () async {
    await connect();
    final senseBox = service(senseBoxServiceUuid, [testCharacteristic]);
    when(() => reactiveBle.getDiscoveredServices(testDeviceId))
        .thenAnswer((_) async => [senseBox]);

    expect(await platform.discoverCharacteristics(), [testCharacteristic]);
  });

  test('discoverCharacteristics fails when the senseBox service is missing',
      () async {
    await connect();
    final battery = service(BleUuid('0000180f-0000-1000-8000-00805f9b34fb'), []);
    when(() => reactiveBle.getDiscoveredServices(testDeviceId))
        .thenAnswer((_) async => [battery]);

    expect(platform.discoverCharacteristics(), throwsStateError);
  });

  test('watchdog drops the connection when data stops arriving', () async {
    when(() => reactiveBle.subscribeToCharacteristic(any()))
        .thenAnswer((_) => Stream.value([0, 0, 0, 0]));
    await connect();
    final states = <BleLinkState>[];
    platform.linkStates.listen(states.add);

    await platform.subscribeToCharacteristic(testCharacteristic).drain<void>();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(connection.hasListener, isFalse);
    expect(platform.isConnected, isFalse);
    expect(states.last, BleLinkState.disconnected);
  });
}

Characteristic _characteristicWithId(BleUuid uuid) {
  final characteristic = _MockCharacteristic();
  when(() => characteristic.id).thenReturn(Uuid.parse(uuid.value));
  return characteristic;
}
