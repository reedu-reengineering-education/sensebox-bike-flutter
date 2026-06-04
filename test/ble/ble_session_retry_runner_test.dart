import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_session_retry_runner.dart';

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

void main() {
  late BleSessionRetryRunner runner;
  late MockBluetoothDevice device;

  setUpAll(() {
    registerFallbackValue(const Duration());
  });

  setUp(() {
    runner = const BleSessionRetryRunner(
      delayBetweenSteps: Duration.zero,
      connectTimeout: Duration(milliseconds: 50),
    );
    device = MockBluetoothDevice();
  });

  group('BleSessionRetryRunner.run', () {
    test('returns true on first successful attempt', () async {
      var prepareCalls = 0;
      var exhausted = false;

      final success = await runner.run(
        device: device,
        maxAttempts: 3,
        attemptSession: (_, __) async => true,
        prepareForRetry: (_) async => prepareCalls++,
        onExhausted: () async => exhausted = true,
      );

      expect(success, isTrue);
      expect(prepareCalls, 0);
      expect(exhausted, isFalse);
    });

    test('retries after failure and returns true when a later attempt succeeds',
        () async {
      var attempt = 0;
      var prepareCalls = 0;

      final success = await runner.run(
        device: device,
        maxAttempts: 3,
        attemptSession: (_, index) async {
          attempt = index;
          return index == 1;
        },
        prepareForRetry: (_) async => prepareCalls++,
      );

      expect(success, isTrue);
      expect(attempt, 1);
      expect(prepareCalls, 1);
    });

    test('returns false and calls onExhausted when all attempts fail', () async {
      var prepareCalls = 0;
      var exhausted = false;

      final success = await runner.run(
        device: device,
        maxAttempts: 2,
        attemptSession: (_, __) async => false,
        prepareForRetry: (_) async => prepareCalls++,
        onExhausted: () async => exhausted = true,
      );

      expect(success, isFalse);
      expect(prepareCalls, 1);
      expect(exhausted, isTrue);
    });

    test('treats thrown attempt errors as failure and continues retrying',
        () async {
      var attempts = 0;

      final success = await runner.run(
        device: device,
        maxAttempts: 2,
        attemptSession: (_, __) async {
          attempts++;
          if (attempts == 1) {
            throw Exception('session failed');
          }
          return true;
        },
        prepareForRetry: (_) async {},
      );

      expect(success, isTrue);
      expect(attempts, 2);
    });

    test('invokes retry lifecycle callbacks', () async {
      var entered = false;
      var exited = false;
      var betweenAttempts = <int>[];

      await runner.run(
        device: device,
        maxAttempts: 2,
        onEnterRetryMode: () => entered = true,
        onExitRetryMode: () => exited = true,
        onBetweenAttempts: betweenAttempts.add,
        attemptSession: (_, index) async => index == 1,
        prepareForRetry: (_) async {},
      );

      expect(entered, isTrue);
      expect(exited, isTrue);
      expect(betweenAttempts, [1]);
    });
  });

  group('BleSessionRetryRunner.prepareDeviceLink', () {
    const linkTimeout = Duration(milliseconds: 50);

    test('disconnects, connects, and does not throw when connect fails',
        () async {
      var disconnected = false;
      when(() => device.connect(timeout: linkTimeout))
          .thenThrow(Exception('connect failed'));

      await runner.prepareDeviceLink(
        device,
        disconnect: () async => disconnected = true,
      );

      expect(disconnected, isTrue);
      verify(() => device.connect(timeout: linkTimeout)).called(1);
    });

    test('completes link preparation when connect succeeds', () async {
      when(() => device.connect(timeout: linkTimeout))
          .thenAnswer((_) async {});

      await runner.prepareDeviceLink(device, disconnect: () async {});

      verify(() => device.connect(timeout: linkTimeout)).called(1);
    });
  });
}
