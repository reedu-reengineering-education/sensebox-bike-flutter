import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/ble/ble_adapter.dart';

void main() {
  group('isBluetoothAdapterEnabled', () {
    test('returns true for on state', () {
      expect(isBluetoothAdapterEnabled(BluetoothAdapterState.on), isTrue);
    });

    test('returns false for off state', () {
      expect(isBluetoothAdapterEnabled(BluetoothAdapterState.off), isFalse);
    });

    test('returns false for unknown state', () {
      expect(
        isBluetoothAdapterEnabled(BluetoothAdapterState.unknown),
        isFalse,
      );
    });
  });
}
