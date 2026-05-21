import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/services/ble/ble_client.dart';
import 'package:sensebox_bike/services/ble/sensebox_data_service.dart';
import 'fake_ble_client.dart';

void main() {
  group('SenseBoxDataService', () {
    late FakeBleClient fakeBleClient;
    late SenseBoxDataService dataService;
    const deviceId = 'device-1';
    const characteristic = BleCharacteristicRef(
      serviceUuid: 'CF06A218-F68E-E0BE-AD04-8EBC1EB0BC84',
      characteristicUuid: 'char-1',
    );

    setUp(() {
      fakeBleClient = FakeBleClient();
      dataService = SenseBoxDataService(fakeBleClient);
    });

    tearDown(() {
      dataService.dispose();
      fakeBleClient.dispose();
    });

    test('validateReceivedData rejects empty and all-zero payloads', () {
      expect(dataService.validateReceivedData(Uint8List(0)), isFalse);
      expect(dataService.validateReceivedData(Uint8List(4)), isFalse);
      expect(
        dataService.validateReceivedData(Uint8List.fromList([1, 2, 3, 4])),
        isTrue,
      );
    });

    test('parseData converts little-endian float32 values', () {
      final bytes = ByteData(8)
        ..setFloat32(0, 1.5, Endian.little)
        ..setFloat32(4, 2.5, Endian.little);

      expect(
        dataService.parseData(bytes.buffer.asUint8List()),
        [1.5, 2.5],
      );
    });

    test('startStreaming exposes parsed characteristic stream', () async {
      fakeBleClient.characteristicsByDevice[deviceId] = [characteristic];

      await dataService.startStreaming(deviceId, [characteristic]);

      final stream = dataService.getCharacteristicStream('char-1');
      final expectation = expectLater(stream, emits([42.0]));

      final payload = ByteData(4)..setFloat32(0, 42.0, Endian.little);
      fakeBleClient.emitNotification(
        deviceId,
        characteristic,
        payload.buffer.asUint8List().toList(),
      );

      await expectation;
    });

    test('clearStreams closes existing subscriptions', () async {
      fakeBleClient.characteristicsByDevice[deviceId] = [characteristic];
      await dataService.startStreaming(deviceId, [characteristic]);
      dataService.clearStreams();

      expect(
        () => dataService.getCharacteristicStream('char-1'),
        throwsException,
      );
    });
  });
}
