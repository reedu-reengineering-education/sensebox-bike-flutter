import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'ble_test_helpers.dart';
import 'mock_ble_platform.dart';

void main() {
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
    when(() => platform.scanForDevices()).thenAnswer((_) => Stream.fromIterable(
        [const BleDevice(id: 'other', name: 'OtherDevice'), testBleDevice]));

    await scanner.startScanning();
    await pumpEventQueue();

    expect(scanner.devicesList, [testBleDevice]);
    expect(isScanning.value, isTrue);
  });

  test('startScanning puts scan errors on the device list stream', () async {
    final scanError = Exception('Bluetooth disabled');
    when(() => platform.scanForDevices())
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
    when(() => platform.scanForDevices()).thenAnswer((_) => Stream.fromIterable(
        [const BleDevice(id: 'other', name: 'senseBox:test'), testBleDevice]));

    final found = await scanner.waitForAdvertisingDevice(testBleDevice,
        shouldCancel: () => false);

    expect(found, testBleDevice);
    expect(isScanning.value, isFalse);
  });

  test('waitForAdvertisingDevice matches by name when no id is given',
      () async {
    when(() => platform.scanForDevices())
        .thenAnswer((_) => Stream.value(testBleDevice));

    final found = await scanner.waitForAdvertisingDevice(
        const BleDevice(id: '', name: 'senseBox:test'),
        shouldCancel: () => false);

    expect(found, testBleDevice);
  });

  test('waitForAdvertisingDevice fails with the scan error', () async {
    final scanError = Exception('Bluetooth disabled');
    when(() => platform.scanForDevices())
        .thenAnswer((_) => Stream.error(scanError));

    await expectLater(
      scanner.waitForAdvertisingDevice(testBleDevice,
          shouldCancel: () => false),
      throwsA(same(scanError)),
    );
    expect(isScanning.value, isFalse);
  });

  test('waitForAdvertisingDevice returns null after the timeout', () async {
    final scan = StreamController<BleDevice>();
    addTearDown(scan.close);
    when(() => platform.scanForDevices()).thenAnswer((_) => scan.stream);

    final found = await scanner.waitForAdvertisingDevice(testBleDevice,
        shouldCancel: () => false, timeout: const Duration(milliseconds: 50));

    expect(found, isNull);
    expect(scan.hasListener, isFalse);
  });
}
