import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_connection_session.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'mock_ble_platform.dart';

Uint8List float32Bytes(List<double> values) {
  final byteData = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    byteData.setFloat32(i * 4, values[i], Endian.little);
  }
  return byteData.buffer.asUint8List();
}

BleService discoveredService({
  required List<BleUuid> characteristics,
}) {
  return BleService(
    serviceId: senseBoxServiceUuid,
    characteristics: characteristics,
  );
}

void main() {
  late MockBlePlatform platform;
  late BleConnectionSession session;
  late BleCharacteristicStreams streams;
  late BleDevice device;
  late StreamController<List<int>> notifyController;
  late BleUuid probeUuid;
  late BleUuid otherUuid;
  late BleService senseBoxService;

  setUpAll(() {
    registerFallbackValue(
      BleCharacteristicRef(
        deviceId: 'AA:BB:CC:DD:EE:01',
        serviceUuid: senseBoxServiceUuid,
        characteristicUuid: BleUuid('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'),
      ),
    );
  });

  setUp(() {
    platform = MockBlePlatform();
    session = BleConnectionSession(
      platform: platform,
      probeTimeout: const Duration(milliseconds: 100),
    );
    streams = BleCharacteristicStreams(platform: platform);
    device = const BleDevice(id: 'AA:BB:CC:DD:EE:01', name: 'senseBox:test');
    notifyController = StreamController<List<int>>.broadcast();

    probeUuid = BleUuid('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
    otherUuid = BleUuid('bbbbbbbb-bbbb-cccc-dddd-eeeeeeeeeeee');
    senseBoxService = discoveredService(
      characteristics: [
        probeUuid,
        otherUuid,
      ],
    );

    when(() => platform.subscribeToCharacteristic(any()))
        .thenAnswer((_) => notifyController.stream);
    when(() => platform.disconnect(any())).thenAnswer((_) async {});
    when(() => platform.isConnected(any())).thenReturn(true);
    when(() => platform.beginSessionEstablishment(any())).thenReturn(null);
    when(() => platform.endSessionEstablishment(any())).thenReturn(null);
  });

  tearDown(() {
    unawaited(streams.clear());
    notifyController.close();
  });

  group('BleConnectionSession', () {
    test('release disconnects device and applies settle delay', () async {
      final stopwatch = Stopwatch()..start();
      await session.release(
        device,
        settle: const Duration(milliseconds: 50),
      );
      stopwatch.stop();

      verify(() => platform.disconnect(device.id)).called(1);
      expect(stopwatch.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 50)));
    });

    test('returns failure when discoverServices is empty', () async {
      when(() => platform.discoverServices(device.id))
          .thenAnswer((_) async => []);

      final result = await session.establish(device, streams: streams);

      expect(result.success, isFalse);
      expect(result.characteristics, isEmpty);
    });

    test('returns failure when senseBox service is missing', () async {
      when(() => platform.discoverServices(device.id)).thenAnswer(
        (_) async => [
          BleService(
            serviceId: BleUuid('00000000-0000-0000-0000-000000000001'),
            characteristics: const [],
          ),
        ],
      );

      final result = await session.establish(device, streams: streams);

      expect(result.success, isFalse);
    });

    test('returns failure when senseBox service has no characteristics', () async {
      when(() => platform.discoverServices(device.id)).thenAnswer(
        (_) async => [
          BleService(
            serviceId: senseBoxServiceUuid,
            characteristics: const [],
          ),
        ],
      );

      final result = await session.establish(device, streams: streams);

      expect(result.success, isFalse);
    });

    test('returns failure when link is not connected', () async {
      when(() => platform.isConnected(device.id)).thenReturn(false);

      final result = await session.establish(device, streams: streams);

      expect(result.success, isFalse);
      verifyNever(() => platform.discoverServices(any()));
    });

    test('returns failure when probe times out', () async {
      when(() => platform.discoverServices(device.id))
          .thenAnswer((_) async => [senseBoxService]);

      final result = await session.establish(device, streams: streams);

      expect(result.success, isFalse);
      verify(() => platform.subscribeToCharacteristic(any())).called(2);
    });

    test('liveness succeeds on zero-valued sensor frames', () async {
      when(() => platform.discoverServices(device.id))
          .thenAnswer((_) async => [senseBoxService]);
      when(() => platform.subscribeToCharacteristic(any()))
          .thenAnswer((_) => Stream.value(List.filled(4, 0)));

      final result = await session.establish(device, streams: streams);

      expect(result.success, isTrue);
    });

    test('liveness succeeds when any characteristic streams data', () async {
      when(() => platform.discoverServices(device.id))
          .thenAnswer((_) async => [senseBoxService]);
      when(() => platform.subscribeToCharacteristic(any())).thenAnswer(
        (invocation) {
          final ref =
              invocation.positionalArguments[0] as BleCharacteristicRef;
          if (ref.characteristicUuid == otherUuid) {
            return Stream.fromFuture(
              Future.microtask(() => float32Bytes([1.0])),
            );
          }
          return notifyController.stream;
        },
      );

      final result = await session.establish(device, streams: streams);

      expect(result.success, isTrue);
      expect(result.characteristics.length, 2);
    });

    test('subscribes all characteristics on valid probe data', () async {
      when(() => platform.discoverServices(device.id))
          .thenAnswer((_) async => [senseBoxService]);
      when(() => platform.subscribeToCharacteristic(any())).thenAnswer(
        (invocation) {
          final ref =
              invocation.positionalArguments[0] as BleCharacteristicRef;
          if (ref.characteristicUuid == probeUuid) {
            return Stream.periodic(
              const Duration(milliseconds: 10),
              (_) => float32Bytes([1.0]),
            );
          }
          return notifyController.stream;
        },
      );

      final result = await session.establish(device, streams: streams);

      expect(result.success, isTrue);
      expect(result.characteristics.length, 2);
      expect(
        streams.subscribedCharacteristicUuids.toList(),
        containsAll([
          probeUuid.toString(),
          otherUuid.toString(),
        ]),
      );
    });

    test('clears existing streams before establishing', () async {
      const existingUuid = 'cccccccc-bbbb-cccc-dddd-eeeeeeeeeeee';
      await streams.subscribe(
        BleCharacteristicRef(
          deviceId: device.id,
          serviceUuid: senseBoxServiceUuid,
          characteristicUuid: BleUuid(existingUuid),
        ),
      );

      when(() => platform.discoverServices(device.id))
          .thenAnswer((_) async => [senseBoxService]);
      when(() => platform.subscribeToCharacteristic(any())).thenAnswer(
        (invocation) {
          final ref =
              invocation.positionalArguments[0] as BleCharacteristicRef;
          if (ref.characteristicUuid == probeUuid) {
            return Stream.fromFuture(
              Future.microtask(() => float32Bytes([2.0])),
            );
          }
          return notifyController.stream;
        },
      );

      await session.establish(device, streams: streams);

      expect(
        streams.subscribedCharacteristicUuids,
        isNot(contains(existingUuid)),
      );
    });

    test('returns failure when stability dwell sees disconnect', () async {
      when(() => platform.discoverServices(device.id))
          .thenAnswer((_) async => [senseBoxService]);
      when(() => platform.isConnected(device.id)).thenReturn(false);
      when(() => platform.subscribeToCharacteristic(any())).thenAnswer(
        (invocation) {
          final ref =
              invocation.positionalArguments[0] as BleCharacteristicRef;
          if (ref.characteristicUuid == probeUuid) {
            return Stream.periodic(
              const Duration(milliseconds: 10),
              (_) => float32Bytes([1.0]),
            );
          }
          return notifyController.stream;
        },
      );

      final result = await session.establish(
        device,
        streams: streams,
        stabilityDwell: const Duration(milliseconds: 50),
      );

      expect(result.success, isFalse);
    });

    test('returns success after stability dwell with ongoing data', () async {
      when(() => platform.discoverServices(device.id))
          .thenAnswer((_) async => [senseBoxService]);
      when(() => platform.isConnected(device.id)).thenReturn(true);
      when(() => platform.subscribeToCharacteristic(any())).thenAnswer(
        (invocation) {
          final ref =
              invocation.positionalArguments[0] as BleCharacteristicRef;
          if (ref.characteristicUuid == probeUuid) {
            return Stream.periodic(
              const Duration(milliseconds: 20),
              (_) => float32Bytes([1.0]),
            );
          }
          return notifyController.stream;
        },
      );

      final result = await session.establish(
        device,
        streams: streams,
        stabilityDwell: const Duration(milliseconds: 50),
      );

      expect(result.success, isTrue);
    });
  });
}
