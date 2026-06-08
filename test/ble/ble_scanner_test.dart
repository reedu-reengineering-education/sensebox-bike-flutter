import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

class MockScanResult extends Mock implements ScanResult {}

class MockAdvertisementData extends Mock implements AdvertisementData {}

void main() {
  setUpAll(() {
    registerFallbackValue(DeviceIdentifier('00:11:22:33:44:55'));
  });

  group('devicesFromScanResults', () {
    test('includes every advertiser without filtering', () {
      final senseBox = MockBluetoothDevice();
      final other = MockBluetoothDevice();
      when(() => senseBox.remoteId).thenReturn(DeviceIdentifier('AA:BB:CC:DD:EE:01'));
      when(() => other.remoteId).thenReturn(DeviceIdentifier('AA:BB:CC:DD:EE:02'));

      final senseBoxAdv = MockAdvertisementData();
      final otherAdv = MockAdvertisementData();
      when(() => senseBoxAdv.advName).thenReturn('senseBox:abc');
      when(() => otherAdv.advName).thenReturn('OtherDevice');

      final senseBoxResult = MockScanResult();
      final otherResult = MockScanResult();
      when(() => senseBoxResult.device).thenReturn(senseBox);
      when(() => senseBoxResult.advertisementData).thenReturn(senseBoxAdv);
      when(() => otherResult.device).thenReturn(other);
      when(() => otherResult.advertisementData).thenReturn(otherAdv);

      expect(
        devicesFromScanResults([otherResult, senseBoxResult]),
        [other, senseBox],
      );
    });
  });

  group('senseBoxDevicesFromScanResults', () {
    test('keeps devices whose advertised name starts with senseBox', () {
      final senseBox = MockBluetoothDevice();
      final other = MockBluetoothDevice();
      final senseBoxId = DeviceIdentifier('AA:BB:CC:DD:EE:01');
      final otherId = DeviceIdentifier('AA:BB:CC:DD:EE:02');
      when(() => senseBox.remoteId).thenReturn(senseBoxId);
      when(() => other.remoteId).thenReturn(otherId);
      when(() => senseBox.advName).thenReturn('');
      when(() => senseBox.platformName).thenReturn('');
      when(() => other.advName).thenReturn('');
      when(() => other.platformName).thenReturn('');

      final senseBoxAdv = MockAdvertisementData();
      final otherAdv = MockAdvertisementData();
      when(() => senseBoxAdv.advName).thenReturn('senseBox:abc');
      when(() => senseBoxAdv.serviceUuids).thenReturn([]);
      when(() => otherAdv.advName).thenReturn('OtherDevice');
      when(() => otherAdv.serviceUuids).thenReturn([]);

      final senseBoxResult = MockScanResult();
      final otherResult = MockScanResult();
      when(() => senseBoxResult.device).thenReturn(senseBox);
      when(() => senseBoxResult.advertisementData).thenReturn(senseBoxAdv);
      when(() => otherResult.device).thenReturn(other);
      when(() => otherResult.advertisementData).thenReturn(otherAdv);

      final filtered = senseBoxDevicesFromScanResults([
        otherResult,
        senseBoxResult,
      ]);

      expect(filtered, [senseBox]);
    });

    test('excludes devices that only advertise a service UUID without name', () {
      final senseBox = MockBluetoothDevice();
      when(() => senseBox.remoteId).thenReturn(DeviceIdentifier('AA:BB:CC:DD:EE:05'));
      when(() => senseBox.advName).thenReturn('');
      when(() => senseBox.platformName).thenReturn('');
      final adv = MockAdvertisementData();
      when(() => adv.advName).thenReturn('');
      when(() => adv.serviceUuids).thenReturn([Guid('0000ffe0-0000-1000-8000-00805f9b34fb')]);
      final result = MockScanResult();
      when(() => result.device).thenReturn(senseBox);
      when(() => result.advertisementData).thenReturn(adv);

      expect(senseBoxDevicesFromScanResults([result]), isEmpty);
    });
  });

  group('BleScanner', () {
    test('devicesListStream is available before scanning', () {
      final scanner = BleScanner(isScanningNotifier: ValueNotifier(false));
      expect(scanner.devicesListStream, isA<Stream<List<BluetoothDevice>>>());
      expect(scanner.devicesList, isEmpty);
      scanner.dispose();
    });
  });
}
