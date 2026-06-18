import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'mock_ble_platform.dart';

BleDevice discovered({
  required String id,
  required String name,
}) {
  return BleDevice(id: id, name: name);
}

void main() {
  group('senseBoxDevicesFromDiscovered', () {
    test('keeps devices whose advertised name starts with senseBox', () {
      final senseBox = discovered(id: 'AA:BB:CC:DD:EE:01', name: 'senseBox:abc');
      final other = discovered(id: 'AA:BB:CC:DD:EE:02', name: 'OtherDevice');

      final filtered = senseBoxDevicesFromDiscovered([other, senseBox]);

      expect(filtered, [BleDevice(id: senseBox.id, name: senseBox.name)]);
    });

    test('excludes devices that only advertise a service UUID without name', () {
      const device = BleDevice(id: 'AA:BB:CC:DD:EE:05', name: '');

      expect(senseBoxDevicesFromDiscovered([device]), isEmpty);
    });
  });

  group('BleScanner', () {
    test('devicesListStream is available before scanning', () {
      final scanner = BleScanner(
        platform: MockBlePlatform(),
        isScanningNotifier: ValueNotifier(false),
      );
      expect(scanner.devicesListStream, isA<Stream<List<BleDevice>>>());
      expect(scanner.devicesList, isEmpty);
      scanner.dispose();
    });
  });
}
