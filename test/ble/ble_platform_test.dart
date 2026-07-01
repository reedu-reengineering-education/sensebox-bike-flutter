import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';

class _MockReactiveBle extends Mock implements FlutterReactiveBle {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isBluetoothAdapterEnabled', () {
    test('returns true for ready state', () {
      expect(isBluetoothAdapterEnabled(BleAdapterState.ready), isTrue);
    });

    test('returns false for poweredOff state', () {
      expect(isBluetoothAdapterEnabled(BleAdapterState.poweredOff), isFalse);
    });

    test('returns false for unknown state', () {
      expect(isBluetoothAdapterEnabled(BleAdapterState.unknown), isFalse);
    });
  });

  const deviceId = 'AA:BB:CC:DD:EE:01';

  group('BlePlatform', () {
    late BlePlatform platform;
    late _MockReactiveBle reactiveBle;

    setUp(() {
      reactiveBle = _MockReactiveBle();
      when(() => reactiveBle.statusStream)
          .thenAnswer((_) => const Stream.empty());
      platform = BlePlatform(reactiveBle: reactiveBle);
    });

    tearDown(() async {
      await platform.dispose();
    });

    test('connectionState exposes a broadcast stream per device', () {
      final stream = platform.connectionState(deviceId);
      expect(stream.isBroadcast, isTrue);
      expect(platform.connectionState(deviceId), isNotNull);
    });

    test('resetRuntimeState keeps active connectionState stream open by default',
        () async {
      var streamClosed = false;
      final sub = platform.connectionState(deviceId).listen(
            (_) {},
            onDone: () => streamClosed = true,
          );

      await platform.resetRuntimeState();
      await Future<void>.delayed(Duration.zero);

      expect(streamClosed, isFalse);
      await sub.cancel();
    });

    test('resetRuntimeState closes active connectionState streams when requested',
        () async {
      var streamClosed = false;
      platform.connectionState(deviceId).listen(
            (_) {},
            onDone: () => streamClosed = true,
          );

      await platform.resetRuntimeState(closeLinkStateControllers: true);
      await Future<void>.delayed(Duration.zero);

      expect(streamClosed, isTrue);
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

    test('connectionState emits disconnected when connection stream closes',
        () async {
      when(
        () => reactiveBle.connectToDevice(
          id: deviceId,
          connectionTimeout: any(named: 'connectionTimeout'),
        ),
      ).thenAnswer(
        (_) => Stream<ConnectionStateUpdate>.fromIterable(
          const [
            ConnectionStateUpdate(
              deviceId: deviceId,
              connectionState: DeviceConnectionState.connected,
              failure: null,
            ),
          ],
        ),
      );

      final statesFuture = platform.connectionState(deviceId).take(3).toList();

      await platform.connect(
        deviceId,
        timeout: const Duration(seconds: 1),
      );

      final states = await statesFuture;
      expect(
        states,
        equals([
          BleLinkState.connecting,
          BleLinkState.connected,
          BleLinkState.disconnected,
        ]),
      );
    });
  });
}
