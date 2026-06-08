import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'mock_ble_platform.dart';

Uint8List float32Bytes(List<double> values) {
  final byteData = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    byteData.setFloat32(i * 4, values[i], Endian.little);
  }
  return byteData.buffer.asUint8List();
}

BleCharacteristicRef characteristicRef(String uuid) {
  return BleCharacteristicRef(
    deviceId: 'AA:BB:CC:DD:EE:01',
    serviceUuid: senseBoxServiceUuid,
    characteristicUuid: BleUuid(uuid),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      BleCharacteristicRef(
        deviceId: 'AA:BB:CC:DD:EE:01',
        serviceUuid: senseBoxServiceUuid,
        characteristicUuid: BleUuid('11111111-2222-3333-4444-555555555555'),
      ),
    );
  });

  group('BleCharacteristicStreams', () {
    late MockBlePlatform platform;
    late BleCharacteristicStreams streams;
    late StreamController<List<int>> notifyController;
    const uuid = '11111111-2222-3333-4444-555555555555';

    setUp(() {
      platform = MockBlePlatform();
      streams = BleCharacteristicStreams(platform: platform);
      notifyController = StreamController<List<int>>.broadcast();

      when(() => platform.subscribeToCharacteristic(any()))
          .thenAnswer((_) => notifyController.stream);
    });

    tearDown(() async {
      await streams.clear();
      await notifyController.close();
    });

    test('characteristicStream throws when uuid is not subscribed', () {
      expect(
        () => streams.characteristicStream(uuid),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Characteristic stream not found for UUID: $uuid'),
        )),
      );
    });

    test('subscribe emits parsed values from platform stream', () async {
      await streams.subscribe(characteristicRef(uuid));

      verify(() => platform.subscribeToCharacteristic(any())).called(1);

      final values = <List<double>>[];
      final subscription =
          streams.characteristicStream(uuid).listen(values.add);

      notifyController.add(float32Bytes([1.0, 2.0]));
      await Future<void>.delayed(Duration.zero);

      expect(values, [
        [1.0, 2.0],
      ]);

      await subscription.cancel();
    });

    test('resubscribe replaces prior stream for the same uuid', () async {
      await streams.subscribe(characteristicRef(uuid));

      final firstValues = <List<double>>[];
      final firstSubscription =
          streams.characteristicStream(uuid).listen(firstValues.add);
      notifyController.add(float32Bytes([1.0]));
      await Future<void>.delayed(Duration.zero);

      await streams.subscribe(characteristicRef(uuid));

      final secondValues = <List<double>>[];
      streams.characteristicStream(uuid).listen(secondValues.add);
      notifyController.add(float32Bytes([2.0]));
      await Future<void>.delayed(Duration.zero);

      expect(firstValues, [
        [1.0],
      ]);
      expect(secondValues, [
        [2.0],
      ]);

      await firstSubscription.cancel();
    });

    test('clear removes subscriptions and closes streams', () async {
      await streams.subscribe(characteristicRef(uuid));
      await streams.clear();

      expect(streams.subscribedCharacteristicUuids, isEmpty);
      expect(
        () => streams.characteristicStream(uuid),
        throwsA(isA<Exception>()),
      );
    });

    test('subscribeAll subscribes every characteristic', () async {
      const secondUuid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      final secondNotify = StreamController<List<int>>.broadcast();

      when(() => platform.subscribeToCharacteristic(any())).thenAnswer(
        (invocation) {
          final ref =
              invocation.positionalArguments[0] as BleCharacteristicRef;
          if (ref.uuidString == secondUuid) {
            return secondNotify.stream;
          }
          return notifyController.stream;
        },
      );

      await streams.subscribeAll([
        characteristicRef(uuid),
        characteristicRef(secondUuid),
      ]);

      expect(
        streams.subscribedCharacteristicUuids.toSet(),
        {uuid, secondUuid},
      );

      await secondNotify.close();
    });
  });
}
