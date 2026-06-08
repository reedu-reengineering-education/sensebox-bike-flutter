import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_helpers.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';

class MockBluetoothCharacteristic extends Mock implements BluetoothCharacteristic {}

Uint8List float32Bytes(List<double> values) {
  final byteData = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    byteData.setFloat32(i * 4, values[i], Endian.little);
  }
  return byteData.buffer.asUint8List();
}

void main() {
  setUpAll(() {
    registerFallbackValue(MockBluetoothCharacteristic());
  });

  group('BleCharacteristicStreams', () {
    late BleCharacteristicStreams streams;
    late MockBluetoothCharacteristic characteristic;
    late StreamController<List<int>> notifyController;
    const uuid = '11111111-2222-3333-4444-555555555555';

    setUp(() {
      streams = BleCharacteristicStreams();
      characteristic = MockBluetoothCharacteristic();
      notifyController = StreamController<List<int>>.broadcast();

      when(() => characteristic.uuid).thenReturn(Guid.fromString(uuid));
      when(() => characteristic.setNotifyValue(any()))
          .thenAnswer((_) async => true);
      when(() => characteristic.onValueReceived)
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

    test('subscribe enables notify and emits parsed values', () async {
      await streams.subscribe(characteristic);

      verify(() => characteristic.setNotifyValue(true)).called(1);

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
      await streams.subscribe(characteristic);

      final firstValues = <List<double>>[];
      final firstSubscription =
          streams.characteristicStream(uuid).listen(firstValues.add);
      notifyController.add(float32Bytes([1.0]));
      await Future<void>.delayed(Duration.zero);

      await streams.subscribe(characteristic);

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
      await streams.subscribe(characteristic);
      await streams.clear();

      expect(streams.subscribedCharacteristicUuids, isEmpty);
      expect(
        () => streams.characteristicStream(uuid),
        throwsA(isA<Exception>()),
      );
    });

    test('subscribeAll subscribes every characteristic', () async {
      final second = MockBluetoothCharacteristic();
      const secondUuid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      final secondNotify = StreamController<List<int>>.broadcast();

      when(() => second.uuid).thenReturn(Guid.fromString(secondUuid));
      when(() => second.setNotifyValue(any())).thenAnswer((_) async => true);
      when(() => second.onValueReceived)
          .thenAnswer((_) => secondNotify.stream);

      await streams.subscribeAll([characteristic, second]);

      expect(
        streams.subscribedCharacteristicUuids.toSet(),
        {uuid, secondUuid},
      );

      await secondNotify.close();
    });
  });
}
