import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/ble_connection_result.dart';

void main() {
  group('BleConnectionResult', () {
    test('aggregateFailureReason returns noData when probes are empty', () {
      expect(
        BleConnectionResult.aggregateFailureReason([]),
        BleConnectionFailureReason.noData,
      );
    });

    test('aggregateFailureReason returns invalidData when all probes invalid with zeros',
        () {
      final probes = [
        const BleCharacteristicProbeResult(
          uuid: 'a',
          isValid: false,
          reason: BleConnectionFailureReason.invalidData,
        ),
        const BleCharacteristicProbeResult(
          uuid: 'b',
          isValid: false,
          reason: BleConnectionFailureReason.invalidData,
        ),
      ];

      expect(
        BleConnectionResult.aggregateFailureReason(probes),
        BleConnectionFailureReason.invalidData,
      );
    });

    test('aggregateFailureReason returns noData when any probe timed out', () {
      final probes = [
        const BleCharacteristicProbeResult(
          uuid: 'a',
          isValid: false,
          reason: BleConnectionFailureReason.invalidData,
        ),
        const BleCharacteristicProbeResult(
          uuid: 'b',
          isValid: false,
          reason: BleConnectionFailureReason.noData,
        ),
      ];

      expect(
        BleConnectionResult.aggregateFailureReason(probes),
        BleConnectionFailureReason.noData,
      );
    });

    test('needsUserDecision result exposes valid and failed uuids', () {
      final result = BleConnectionResult.needsUserDecision(probes: [
        const BleCharacteristicProbeResult(uuid: 'valid-uuid', isValid: true),
        const BleCharacteristicProbeResult(
          uuid: 'failed-uuid',
          isValid: false,
          reason: BleConnectionFailureReason.noData,
        ),
      ]);

      expect(result.validUuids, ['valid-uuid']);
      expect(result.failedUuids, ['failed-uuid']);
      expect(result.needsUserDecision, isTrue);
      expect(result.success, isFalse);
    });
  });
}
