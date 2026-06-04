import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';
import 'package:sensebox_bike/secrets.dart';

class MockBluetoothService extends Mock implements BluetoothService {}

Uint8List float32Bytes(List<double> values) {
  final byteData = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    byteData.setFloat32(i * 4, values[i], Endian.little);
  }
  return byteData.buffer.asUint8List();
}

void main() {
  group('parseCharacteristicPayload', () {
    test('parses little-endian float32 values in 4-byte chunks', () {
      expect(parseCharacteristicPayload(float32Bytes([1.0, 2.5])), [1.0, 2.5]);
    });

    test('ignores trailing bytes shorter than 4', () {
      final payload = Uint8List.fromList([...float32Bytes([3.0]), 0x01, 0x02]);
      expect(parseCharacteristicPayload(payload), [3.0]);
    });

    test('returns empty list for empty input', () {
      expect(parseCharacteristicPayload(Uint8List(0)), isEmpty);
    });

    test('parses multiple float32 values', () {
      expect(
        parseCharacteristicPayload(float32Bytes([0.0, -1.5, 42.0])),
        [0.0, -1.5, 42.0],
      );
    });
  });

  group('isValidCharacteristicPayload', () {
    test('rejects empty payload', () {
      expect(isValidCharacteristicPayload(Uint8List(0)), isFalse);
    });

    test('rejects all-zero payload', () {
      expect(isValidCharacteristicPayload(Uint8List(8)), isFalse);
    });

    test('rejects payload shorter than 4 bytes', () {
      expect(isValidCharacteristicPayload(Uint8List.fromList([1, 2, 3])), isFalse);
    });

    test('accepts non-zero payload with at least 4 bytes', () {
      expect(isValidCharacteristicPayload(float32Bytes([1.0])), isTrue);
    });

    test('accepts payload with single non-zero byte in first chunk', () {
      expect(
        isValidCharacteristicPayload(Uint8List.fromList([0, 0, 0, 1])),
        isTrue,
      );
    });

    test('rejects payload that is only zero padding beyond 4 bytes', () {
      expect(isValidCharacteristicPayload(Uint8List(12)), isFalse);
    });
  });

  group('findSenseBoxService', () {
    test('returns service matching senseBoxServiceUUID', () {
      final senseBox = MockBluetoothService();
      final other = MockBluetoothService();
      when(() => senseBox.uuid).thenReturn(senseBoxServiceUUID);
      when(() => other.uuid).thenReturn(
        Guid.fromString('0000180f-0000-1000-8000-00805f9b34fb'),
      );

      expect(findSenseBoxService([other, senseBox]), senseBox);
    });

    test('throws when senseBox service is missing', () {
      final other = MockBluetoothService();
      when(() => other.uuid).thenReturn(
        Guid.fromString('0000180f-0000-1000-8000-00805f9b34fb'),
      );

      expect(
        () => findSenseBoxService([other]),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('senseBox service not found'),
        )),
      );
    });
  });
}
