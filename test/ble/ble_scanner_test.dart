import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

class MockScanResult extends Mock implements ScanResult {}

void main() {
  group('senseBoxDevicesFromScanResults', () {
    test('keeps only devices whose platform name starts with senseBox', () {
      final senseBox = MockBluetoothDevice();
      final other = MockBluetoothDevice();
      when(() => senseBox.platformName).thenReturn('senseBox:abc');
      when(() => other.platformName).thenReturn('OtherDevice');

      final senseBoxResult = MockScanResult();
      final otherResult = MockScanResult();
      when(() => senseBoxResult.device).thenReturn(senseBox);
      when(() => otherResult.device).thenReturn(other);

      final filtered = senseBoxDevicesFromScanResults([
        otherResult,
        senseBoxResult,
      ]);

      expect(filtered, [senseBox]);
    });

    test('returns empty list when no matching devices', () {
      final other = MockBluetoothDevice();
      when(() => other.platformName).thenReturn('not-senseBox');
      final result = MockScanResult();
      when(() => result.device).thenReturn(other);

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
