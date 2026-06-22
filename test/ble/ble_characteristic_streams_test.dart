import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'ble_test_helpers.dart';
import 'mock_ble_platform.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      testCharacteristicRef('11111111-2222-3333-4444-555555555555'),
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
      await streams.subscribe(testCharacteristicRef(uuid));

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
      await streams.subscribe(testCharacteristicRef(uuid));

      final firstValues = <List<double>>[];
      final firstSubscription =
          streams.characteristicStream(uuid).listen(firstValues.add);
      notifyController.add(float32Bytes([1.0]));
      await Future<void>.delayed(Duration.zero);

      await streams.subscribe(testCharacteristicRef(uuid));

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
      await streams.subscribe(testCharacteristicRef(uuid));
      await streams.clear();

      expect(streams.subscribedCharacteristicUuids, isEmpty);
      expect(
        () => streams.characteristicStream(uuid),
        throwsA(isA<Exception>()),
      );
    });
  });
}
