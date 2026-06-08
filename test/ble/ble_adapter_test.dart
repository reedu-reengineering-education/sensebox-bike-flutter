import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ble/ble_adapter.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';

void main() {
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
}
