import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'ble_test_helpers.dart';
import 'mock_ble_platform.dart';

void main() {
  late MockBlePlatform platform;
  late BleScanner scanner;

  setUpAll(registerBleFallbackValues);

  setUp(() {
    platform = MockBlePlatform();
    scanner = BleScanner(platform);
    addTearDown(scanner.dispose);
  });

  List<List<BleUuid>> scanFilters() => verify(() => platform.scanForDevices(
          withServices: captureAny(named: 'withServices')))
      .captured
      .cast<List<BleUuid>>();

  group('scanForDevices', () {
    test('lists each senseBox device once, without a filter', () async {
      final scan = StreamController<BleDevice>();
      addTearDown(scan.close);
      stubScan(platform, scan.stream);

      final lists = <List<BleDevice>>[];
      final subscription = scanner.scanForDevices().listen(lists.add);
      scan
        ..add(const BleDevice(id: 'other', name: 'OtherDevice'))
        ..add(testBleDevice)
        ..add(testBleDevice);
      await pumpEventQueue();
      await subscription.cancel();

      expect(lists, [
        [testBleDevice],
        [testBleDevice],
      ]);
      expect(scanFilters().single, isEmpty);
      expect(scan.hasListener, isFalse);
    });

    test('forwards scan errors and ends', () async {
      final scanError = Exception('Bluetooth disabled');
      stubScan(platform, Stream.error(scanError));

      await expectLater(
        scanner.scanForDevices(),
        emitsInOrder([emitsError(same(scanError)), emitsDone]),
      );
    });

    test('ends when the scan is stopped', () async {
      final scan = StreamController<BleDevice>();
      addTearDown(scan.close);
      stubScan(platform, scan.stream);

      final done = expectLater(scanner.scanForDevices(), emitsDone);
      await pumpEventQueue();
      await scanner.stopScanning();

      await done;
    });
  });

  group('waitForAdvertisingDevice', () {
    test('returns the device with the same id', () async {
      stubScan(
        platform,
        Stream.fromIterable([
          const BleDevice(id: 'other', name: 'senseBox:test'),
          testBleDevice,
        ]),
      );

      expect(
        await scanner.waitForAdvertisingDevice(testBleDevice),
        testBleDevice,
      );
    });

    test('matches by name when no id is given', () async {
      stubScan(platform, Stream.value(testBleDevice));

      final found = await scanner.waitForAdvertisingDevice(
        const BleDevice(id: '', name: 'senseBox:test'),
      );

      expect(found, testBleDevice);
    });

    test('fails with the scan error', () async {
      final scanError = Exception('Bluetooth disabled');
      stubScan(platform, Stream.error(scanError));

      await expectLater(
        scanner.waitForAdvertisingDevice(testBleDevice),
        throwsA(same(scanError)),
      );
    });

    test('returns null after the timeout and stops the scan', () async {
      final scan = StreamController<BleDevice>();
      addTearDown(scan.close);
      stubScan(platform, scan.stream);

      final found = await scanner.waitForAdvertisingDevice(
        testBleDevice,
        timeout: const Duration(milliseconds: 50),
      );

      expect(found, isNull);
      expect(scan.hasListener, isFalse);
    });

    test('returns null when the scan is stopped', () async {
      final scan = StreamController<BleDevice>();
      addTearDown(scan.close);
      stubScan(platform, scan.stream);

      final waiting = scanner.waitForAdvertisingDevice(testBleDevice);
      await pumpEventQueue();
      await scanner.stopScanning();

      expect(await waiting, isNull);
      expect(scan.hasListener, isFalse);
    });
  });

  group('scan filter', () {
    BleDevice advertising(String uuid) => BleDevice(
          id: testBleDevice.id,
          name: testBleDevice.name,
          serviceUuids: [BleUuid(uuid)],
        );
    const bootUuid = '2456e1b9-26e2-8f83-e744-f34f01e9d701';
    const runningUuid = 'cddf0001-30f7-4671-8b43-5e40ba53514a';

    test('filters by every service a box advertised in earlier scans',
        () async {
      final results = [advertising(bootUuid), advertising(runningUuid)];
      when(() => platform.scanForDevices(
              withServices: any(named: 'withServices')))
          .thenAnswer((_) => Stream.value(results.removeAt(0)));
      await scanner.waitForAdvertisingDevice(testBleDevice);
      await scanner.waitForAdvertisingDevice(testBleDevice);
      stubScan(platform, Stream.value(testBleDevice));

      await scanner.waitForAdvertisingDevice(testBleDevice);

      final filters = scanFilters();
      expect(filters.first, isEmpty);
      expect(filters.last.toSet(), {BleUuid(bootUuid), BleUuid(runningUuid)});
    });

    test('scans unfiltered once after a filtered scan missed the box',
        () async {
      stubScan(platform, Stream.value(advertising(bootUuid)));
      await scanner.waitForAdvertisingDevice(testBleDevice);
      final silent = StreamController<BleDevice>();
      addTearDown(silent.close);
      stubScan(platform, silent.stream);
      await scanner.waitForAdvertisingDevice(
        testBleDevice,
        timeout: const Duration(milliseconds: 20),
      );
      stubScan(platform, Stream.value(advertising(runningUuid)));

      final found = await scanner.waitForAdvertisingDevice(testBleDevice);
      await scanner.waitForAdvertisingDevice(testBleDevice);

      final filters = scanFilters();
      expect(found, testBleDevice);
      expect(filters[1], [BleUuid(bootUuid)]);
      expect(filters[2], isEmpty);
      expect(filters[3].toSet(), {BleUuid(bootUuid), BleUuid(runningUuid)});
    });
  });
}
