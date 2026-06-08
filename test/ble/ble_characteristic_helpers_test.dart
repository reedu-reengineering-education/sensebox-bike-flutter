import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';

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
    test('returns service matching senseBoxServiceUuid', () {
      final senseBox = BleService(
        serviceId: senseBoxServiceUuid,
        characteristics: const [],
      );
      final other = BleService(
        serviceId: BleUuid('0000180f-0000-1000-8000-00805f9b34fb'),
        characteristics: const [],
      );

      expect(findSenseBoxService([other, senseBox]), senseBox);
    });

    test('throws when senseBox service is missing', () {
      final other = BleService(
        serviceId: BleUuid('0000180f-0000-1000-8000-00805f9b34fb'),
        characteristics: const [],
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

  group('characteristicRefsFromService', () {
    test('builds refs for every discovered characteristic', () {
      const deviceId = 'AA:BB:CC:DD:EE:01';
      final charUuid = BleUuid('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
      final service = BleService(
        serviceId: senseBoxServiceUuid,
        characteristics: [charUuid],
      );

      final refs = characteristicRefsFromService(
        deviceId: deviceId,
        service: service,
      );

      expect(refs.length, 1);
      expect(refs.first.deviceId, deviceId);
      expect(refs.first.serviceUuid, senseBoxServiceUuid);
      expect(refs.first.characteristicUuid, charUuid);
    });
  });
}
