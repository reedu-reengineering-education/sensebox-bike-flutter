import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_connection_session.dart';
import 'package:sensebox_bike/secrets.dart';

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

class MockBluetoothService extends Mock implements BluetoothService {}

class MockBluetoothCharacteristic extends Mock implements BluetoothCharacteristic {}

Uint8List float32Bytes(List<double> values) {
  final byteData = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    byteData.setFloat32(i * 4, values[i], Endian.little);
  }
  return byteData.buffer.asUint8List();
}

void main() {
  late BleConnectionSession session;
  late BleCharacteristicStreams streams;
  late MockBluetoothDevice device;
  late MockBluetoothService senseBoxService;
  late MockBluetoothCharacteristic probeCharacteristic;
  late MockBluetoothCharacteristic otherCharacteristic;
  late StreamController<List<int>> notifyController;

  setUpAll(() {
    registerFallbackValue(MockBluetoothCharacteristic());
  });

  setUp(() {
    session = const BleConnectionSession(
      probeTimeout: Duration(milliseconds: 100),
    );
    streams = BleCharacteristicStreams();
    device = MockBluetoothDevice();
    senseBoxService = MockBluetoothService();
    probeCharacteristic = MockBluetoothCharacteristic();
    otherCharacteristic = MockBluetoothCharacteristic();
    notifyController = StreamController<List<int>>.broadcast();

    when(() => senseBoxService.uuid).thenReturn(senseBoxServiceUUID);
    when(() => senseBoxService.characteristics)
        .thenReturn([probeCharacteristic, otherCharacteristic]);

    when(() => probeCharacteristic.uuid)
        .thenReturn(Guid.fromString('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'));
    when(() => otherCharacteristic.uuid)
        .thenReturn(Guid.fromString('bbbbbbbb-bbbb-cccc-dddd-eeeeeeeeeeee'));

    for (final characteristic in [probeCharacteristic, otherCharacteristic]) {
      when(() => characteristic.setNotifyValue(any()))
          .thenAnswer((_) async => true);
      when(() => characteristic.onValueReceived)
          .thenAnswer((_) => notifyController.stream);
    }
  });

  tearDown(() {
    unawaited(streams.clear());
    notifyController.close();
  });

  group('BleConnectionSession', () {
    test('release disconnects device and applies settle delay', () async {
      when(() => device.disconnect()).thenAnswer((_) async {});

      final stopwatch = Stopwatch()..start();
      await session.release(
        device,
        settle: const Duration(milliseconds: 50),
      );
      stopwatch.stop();

      verify(() => device.disconnect()).called(1);
      expect(stopwatch.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 50)));
    });

    test('returns failure when discoverServices is empty', () async {
      when(() => device.discoverServices()).thenAnswer((_) async => []);

      final result = await session.establish(device, streams: streams);

      expect(result.success, isFalse);
      expect(result.characteristics, isEmpty);
    });

    test('returns failure when senseBox service is missing', () async {
      final otherService = MockBluetoothService();
      when(() => otherService.uuid).thenReturn(
        Guid.fromString('00000000-0000-0000-0000-000000000001'),
      );
      when(() => device.discoverServices())
          .thenAnswer((_) async => [otherService]);

      final result = await session.establish(device, streams: streams);

      expect(result.success, isFalse);
    });

    test('returns failure when senseBox service has no characteristics', () async {
      when(() => senseBoxService.characteristics).thenReturn([]);
      when(() => device.discoverServices())
          .thenAnswer((_) async => [senseBoxService]);

      final result = await session.establish(device, streams: streams);

      expect(result.success, isFalse);
    });

    test('returns failure when probe times out', () async {
      when(() => device.discoverServices())
          .thenAnswer((_) async => [senseBoxService]);

      final result = await session.establish(device, streams: streams);

      expect(result.success, isFalse);
      verify(() => probeCharacteristic.setNotifyValue(true)).called(1);
      verify(() => probeCharacteristic.setNotifyValue(false)).called(1);
    });

    test('returns failure when probe payload is all zeros', () async {
      when(() => device.discoverServices())
          .thenAnswer((_) async => [senseBoxService]);
      when(() => probeCharacteristic.onValueReceived)
          .thenAnswer((_) => Stream.value(List.filled(4, 0)));

      final result = await session.establish(device, streams: streams);

      expect(result.success, isFalse);
    });

    test('subscribes all characteristics on valid probe data', () async {
      when(() => device.discoverServices())
          .thenAnswer((_) async => [senseBoxService]);
      when(() => probeCharacteristic.onValueReceived)
          .thenAnswer((_) => Stream.value(float32Bytes([1.0])));

      final result = await session.establish(device, streams: streams);

      expect(result.success, isTrue);
      expect(result.characteristics, senseBoxService.characteristics);
      expect(
        streams.subscribedCharacteristicUuids.toList(),
        containsAll([
          probeCharacteristic.uuid.toString(),
          otherCharacteristic.uuid.toString(),
        ]),
      );
      verify(() => probeCharacteristic.setNotifyValue(false)).called(1);
    });

    test('clears existing streams before establishing', () async {
      final existing = MockBluetoothCharacteristic();
      when(() => existing.uuid)
          .thenReturn(Guid.fromString('cccccccc-bbbb-cccc-dddd-eeeeeeeeeeee'));
      when(() => existing.setNotifyValue(any())).thenAnswer((_) async => true);
      when(() => existing.onValueReceived)
          .thenAnswer((_) => const Stream.empty());
      await streams.subscribe(existing);

      when(() => device.discoverServices())
          .thenAnswer((_) async => [senseBoxService]);
      when(() => probeCharacteristic.onValueReceived)
          .thenAnswer((_) => Stream.value(float32Bytes([2.0])));

      await session.establish(device, streams: streams);

      expect(
        streams.subscribedCharacteristicUuids,
        isNot(contains(existing.uuid.toString())),
      );
    });
  });
}
