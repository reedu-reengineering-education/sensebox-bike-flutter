import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/ble_connection_result.dart';

void main() {
  group('BleConnectionResult', () {
    test('fullSuccess marks result as successful', () {
      final result = BleConnectionResult.fullSuccess();

      expect(result.success, isTrue);
      expect(result.failureReason, isNull);
    });

    test('failure exposes the failure reason', () {
      final result = BleConnectionResult.failure(
        reason: BleConnectionFailureReason.noData,
      );

      expect(result.success, isFalse);
      expect(result.failureReason, BleConnectionFailureReason.noData);
    });
  });

  group('BleConnectionResult.fromException', () {
    test('maps timeout errors to connectionTimeout', () {
      expect(
        BleConnectionResult.fromException(
          Exception('[FBP] connection timeout'),
        ),
        BleConnectionFailureReason.connectionTimeout,
      );
    });

    test('maps disconnect errors to connectionLost', () {
      expect(
        BleConnectionResult.fromException(
          Exception('device disconnected'),
        ),
        BleConnectionFailureReason.connectionLost,
      );
    });
  });
}
