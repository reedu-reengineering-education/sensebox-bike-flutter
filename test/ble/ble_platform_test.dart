import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';

void main() {
  const deviceId = 'AA:BB:CC:DD:EE:01';

  group('BlePlatform', () {
    late BlePlatform platform;

    setUp(() {
      platform = BlePlatform();
    });

    tearDown(() async {
      await platform.dispose();
    });

    test('connectionState exposes a broadcast stream per device', () {
      final stream = platform.connectionState(deviceId);
      expect(stream.isBroadcast, isTrue);
      // Calling again is backed by the same controller and does not throw.
      expect(platform.connectionState(deviceId), isNotNull);
    });

    test('isConnected is false before connecting', () {
      expect(platform.isConnected(deviceId), isFalse);
    });

    test('subscribeToCharacteristic errors when characteristic is unknown',
        () async {
      final ref = BleCharacteristicRef(
        deviceId: deviceId,
        serviceUuid: senseBoxServiceUuid,
        characteristicUuid: BleUuid('11111111-2222-3333-4444-555555555555'),
      );

      await expectLater(
        platform.subscribeToCharacteristic(ref),
        emitsError(isA<StateError>()),
      );
    });
  });
}
