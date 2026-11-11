import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'ble_test_helpers.dart';
import 'mock_ble_platform.dart';

void main() {
  setUpAll(() => registerFallbackValue(<BleUuid>[]));

  late MockBlePlatform platform;
  late ValueNotifier<bool> isScanning;
  late BleScanner scanner;

  setUp(() {
    platform = MockBlePlatform();
    isScanning = ValueNotifier(false);
    scanner = BleScanner(platform: platform, isScanningNotifier: isScanning);
    addTearDown(scanner.dispose);
  });

  test('devicesListStream is available before scanning', () {
    expect(scanner.devicesListStream, isA<Stream<List<BleDevice>>>());
    expect(scanner.devicesList, isEmpty);
  });

  test('startScanning lists only senseBox devices', () async {
    when(() => platform.scanForDevices(withServices: any(named: 'withServices'))).thenAnswer((_) => Stream.fromIterable(
        [const BleDevice(id: 'other', name: 'OtherDevice'), testBleDevice]));

    await scanner.startScanning();
    await pumpEventQueue();

    expect(scanner.devicesList, [testBleDevice]);
    expect(isScanning.value, isTrue);
  });

  test('startScanning puts scan errors on the device list stream', () async {
    final scanError = Exception('Bluetooth disabled');
    when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
        .thenAnswer((_) => Stream.error(scanError));

    final emitted = expectLater(
      scanner.devicesListStream,
      emitsThrough(emitsError(same(scanError))),
    );
    await scanner.startScanning();

    await emitted;
    expect(isScanning.value, isFalse);
  });

  test('waitForAdvertisingDevice returns the device with the same id',
      () async {
    when(() => platform.scanForDevices(withServices: any(named: 'withServices'))).thenAnswer((_) => Stream.fromIterable(
        [const BleDevice(id: 'other', name: 'senseBox:test'), testBleDevice]));

    final found = await scanner.waitForAdvertisingDevice(testBleDevice);

    expect(found, testBleDevice);
    expect(isScanning.value, isFalse);
  });

  BleDevice advertising(String uuid) => BleDevice(
        id: testBleDevice.id,
        name: testBleDevice.name,
        serviceUuids: [BleUuid(uuid)],
      );

  const bootUuid = '2456e1b9-26e2-8f83-e744-f34f01e9d701';
  const runningUuid = 'cddf0001-30f7-4671-8b43-5e40ba53514a';

  test('filters by every service a box advertised in earlier scans', () async {
    final results = [advertising(bootUuid), advertising(runningUuid)];
    when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
        .thenAnswer((_) => Stream.value(results.removeAt(0)));
    await scanner.waitForAdvertisingDevice(testBleDevice);
    await scanner.waitForAdvertisingDevice(testBleDevice);
    when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
        .thenAnswer((_) => Stream.value(testBleDevice));

    await scanner.waitForAdvertisingDevice(testBleDevice);

    final filters = verify(() => platform.scanForDevices(
            withServices: captureAny(named: 'withServices')))
        .captured
        .cast<List<BleUuid>>();
    expect(filters.first, isEmpty);
    expect(filters.last.toSet(), {BleUuid(bootUuid), BleUuid(runningUuid)});
  });

  test('scans unfiltered once after a filtered scan missed the box', () async {
    when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
        .thenAnswer((_) => Stream.value(advertising(bootUuid)));
    await scanner.waitForAdvertisingDevice(testBleDevice);
    final silent = StreamController<BleDevice>();
    addTearDown(silent.close);
    when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
        .thenAnswer((_) => silent.stream);
    await scanner.waitForAdvertisingDevice(testBleDevice,
        timeout: const Duration(milliseconds: 20));
    when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
        .thenAnswer((_) => Stream.value(advertising(runningUuid)));

    final found = await scanner.waitForAdvertisingDevice(testBleDevice);
    await scanner.waitForAdvertisingDevice(testBleDevice);

    final filters = verify(() => platform.scanForDevices(
            withServices: captureAny(named: 'withServices')))
        .captured
        .cast<List<BleUuid>>();
    expect(found, testBleDevice);
    expect(filters[1], [BleUuid(bootUuid)]);
    expect(filters[2], isEmpty);
    expect(filters[3].toSet(), {BleUuid(bootUuid), BleUuid(runningUuid)});
  });

  test('startScanning does not filter by service', () async {
    when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
        .thenAnswer((_) => const Stream.empty());

    await scanner.startScanning();

    verify(() => platform.scanForDevices(withServices: const [])).called(1);
  });

  test('waitForAdvertisingDevice matches by name when no id is given',
      () async {
    when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
        .thenAnswer((_) => Stream.value(testBleDevice));

    final found = await scanner.waitForAdvertisingDevice(
        const BleDevice(id: '', name: 'senseBox:test'));

    expect(found, testBleDevice);
  });

  test('waitForAdvertisingDevice fails with the scan error', () async {
    final scanError = Exception('Bluetooth disabled');
    when(() => platform.scanForDevices(withServices: any(named: 'withServices')))
        .thenAnswer((_) => Stream.error(scanError));

    await expectLater(
      scanner.waitForAdvertisingDevice(testBleDevice),
      throwsA(same(scanError)),
    );
    expect(isScanning.value, isFalse);
  });

  test('stopScanning ends a pending wait with no device', () async {
    final scan = StreamController<BleDevice>();
    addTearDown(scan.close);
    when(() => platform.scanForDevices(withServices: any(named: 'withServices'))).thenAnswer((_) => scan.stream);

    final waiting = scanner.waitForAdvertisingDevice(testBleDevice);
    await pumpEventQueue();
    await scanner.stopScanning();

    expect(await waiting, isNull);
    expect(scan.hasListener, isFalse);
  });

  test('waitForAdvertisingDevice returns null after the timeout', () async {
    final scan = StreamController<BleDevice>();
    addTearDown(scan.close);
    when(() => platform.scanForDevices(withServices: any(named: 'withServices'))).thenAnswer((_) => scan.stream);

    final found = await scanner.waitForAdvertisingDevice(testBleDevice,
        timeout: const Duration(milliseconds: 50));

    expect(found, isNull);
    expect(scan.hasListener, isFalse);
  });
}
