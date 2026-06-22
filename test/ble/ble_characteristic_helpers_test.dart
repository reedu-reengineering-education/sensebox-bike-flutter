import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
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
      final charUuid = BleUuid('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
      final service = BleService(
        serviceId: senseBoxServiceUuid,
        characteristics: [charUuid],
      );

      final refs = characteristicRefsFromService(
        deviceId: testDeviceId,
        service: service,
      );

      expect(refs.length, 1);
      expect(refs.first.deviceId, testDeviceId);
      expect(refs.first.serviceUuid, senseBoxServiceUuid);
      expect(refs.first.characteristicUuid, charUuid);
    });
  });
}
