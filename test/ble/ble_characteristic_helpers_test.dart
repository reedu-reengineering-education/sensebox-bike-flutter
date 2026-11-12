import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';
import 'ble_test_helpers.dart';

void main() {
  group('parseCharacteristicPayload', () {
    test('parses little-endian float32 values in 4-byte chunks', () {
      expect(parseCharacteristicPayload(float32Bytes([1.0, 2.5])), [1.0, 2.5]);
      expect(
        parseCharacteristicPayload(float32Bytes([0.0, -1.5, 42.0])),
        [0.0, -1.5, 42.0],
      );
    });

    test('ignores trailing bytes shorter than 4', () {
      final payload =
          Uint8List.fromList([...float32Bytes([3.0]), 0x01, 0x02]);
      expect(parseCharacteristicPayload(payload), [3.0]);
    });

    test('returns empty list for empty input', () {
      expect(parseCharacteristicPayload(float32Bytes([])), isEmpty);
    });
  });
}
