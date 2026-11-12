import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'ble_test_helpers.dart';
import 'mock_ble_platform.dart';

void main() {
  late MockBlePlatform platform;
  late BleCharacteristicStreams streams;
  late StreamController<List<int>> silent;
  final other = BleUuid('bbbbbbbb-bbbb-cccc-dddd-eeeeeeeeeeee');
  final third = BleUuid('cccccccc-bbbb-cccc-dddd-eeeeeeeeeeee');

  setUpAll(registerBleFallbackValues);

  setUp(() {
    platform = MockBlePlatform();
    streams = BleCharacteristicStreams(
      platform: platform,
      probeTimeout: const Duration(milliseconds: 100),
    );
    silent = StreamController<List<int>>.broadcast();
    when(() => platform.discoverCharacteristics())
        .thenAnswer((_) async => [testCharacteristic, other]);
    when(() => platform.subscribeToCharacteristic(any()))
        .thenAnswer((_) => silent.stream);
  });

  tearDown(() async {
    await streams.clear();
    await silent.close();
  });

  void stubData(BleUuid characteristic, List<double> values) {
    when(() => platform.subscribeToCharacteristic(characteristic))
        .thenAnswer((_) => Stream.value(float32Bytes(values)));
  }

  test('characteristicStream throws when uuid is not subscribed', () {
    expect(() => streams.characteristicStream('$testCharacteristic'),
        throwsStateError);
  });

  test('establish fails when the box has no characteristics', () async {
    when(() => platform.discoverCharacteristics()).thenAnswer((_) async => []);

    expect(streams.establish(), throwsStateError);
  });

  test('establish fails when discovery fails', () async {
    when(() => platform.discoverCharacteristics())
        .thenThrow(StateError('senseBox service not found'));

    expect(streams.establish(), throwsStateError);
  });

  test('establish times out when no data arrives', () async {
    await expectLater(streams.establish(), throwsA(isA<TimeoutException>()));
    verify(() => platform.subscribeToCharacteristic(any())).called(2);
  });

  test('establish succeeds on zero-valued sensor frames', () async {
    stubData(other, [0.0]);

    expect(await streams.establish(), [testCharacteristic, other]);
  });

  test('establish subscribes every characteristic even when data arrives early',
      () async {
    when(() => platform.discoverCharacteristics())
        .thenAnswer((_) async => [testCharacteristic, other, third]);
    stubData(testCharacteristic, [1.0]);

    await streams.establish();

    for (final uuid in [testCharacteristic, other, third]) {
      expect(streams.characteristicStream('$uuid'), isNotNull);
    }
  });

  test('establish replaces the streams of an earlier session', () async {
    stubData(testCharacteristic, [1.0]);
    await streams.establish();
    when(() => platform.discoverCharacteristics())
        .thenAnswer((_) async => [other]);
    stubData(other, [2.0]);

    await streams.establish();

    expect(() => streams.characteristicStream('$testCharacteristic'),
        throwsStateError);
    expect(streams.characteristicStream('$other'), isNotNull);
  });

  test('streams parsed values and tracks which characteristics are live',
      () async {
    stubData(other, [1.0]);
    await streams.establish();
    final values = <List<double>>[];
    streams.characteristicStream('$testCharacteristic').listen(values.add);

    silent.add(float32Bytes([1.5, 2.5]));
    await pumpEventQueue();

    expect(values, [
      [1.5, 2.5]
    ]);
    expect(streams.hasLivePayload('$testCharacteristic'), isTrue);
    expect(streams.hasLivePayload('$other'), isTrue);
  });

  test('clear closes streams and forgets live payloads', () async {
    stubData(other, [1.0]);
    await streams.establish();

    await streams.clear();

    expect(() => streams.characteristicStream('$other'), throwsStateError);
    expect(streams.hasLivePayload('$other'), isFalse);
  });
}
