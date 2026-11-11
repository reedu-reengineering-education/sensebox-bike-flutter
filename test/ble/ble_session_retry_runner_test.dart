import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_session_retry_runner.dart';

void main() {
  late BleSessionRetryRunner runner;
  late BleDevice device;

  setUp(() {
    runner = BleSessionRetryRunner(
      delayBetweenSteps: Duration.zero,
    );
    device = const BleDevice(id: 'AA:BB:CC:DD:EE:01', name: 'senseBox:test');
  });

  group('BleSessionRetryRunner.run', () {
    Future<BleSessionRetryResult> runAttempts(
      int attempts, {
      required Future<bool> Function(BleDevice device, int attemptIndex)
          attemptSession,
      required Future<void> Function(BleDevice device) prepareForRetry,
    }) {
      var started = 0;
      return runner.run(
        device: device,
        timeLimit: const Duration(minutes: 1),
        shouldStop: () => started >= attempts,
        attemptSession: (device, index) {
          started++;
          return attemptSession(device, index);
        },
        prepareForRetry: prepareForRetry,
      );
    }

    test('stops retrying once the time limit is reached', () async {
      var attempts = 0;
      var prepareCalls = 0;

      final result = await runner.run(
        device: device,
        timeLimit: Duration.zero,
        shouldStop: () => false,
        attemptSession: (_, __) async {
          attempts++;
          return false;
        },
        prepareForRetry: (_) async => prepareCalls++,
      );

      expect(result.success, isFalse);
      expect(attempts, 1);
      expect(prepareCalls, 0);
    });

    test('does not attempt when asked to stop', () async {
      var attempts = 0;

      final result = await runner.run(
        device: device,
        timeLimit: const Duration(minutes: 1),
        shouldStop: () => true,
        attemptSession: (_, __) async {
          attempts++;
          return true;
        },
        prepareForRetry: (_) async {},
      );

      expect(result.success, isFalse);
      expect(attempts, 0);
    });

    test('succeeds on first successful attempt', () async {
      var prepareCalls = 0;

      final result = await runAttempts(
        3,
        attemptSession: (_, __) async => true,
        prepareForRetry: (_) async => prepareCalls++,
      );

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(prepareCalls, 0);
    });

    test('retries after failure and succeeds when a later attempt succeeds',
        () async {
      var attempt = 0;
      var prepareCalls = 0;

      final result = await runAttempts(
        3,
        attemptSession: (_, index) async {
          attempt = index;
          return index == 1;
        },
        prepareForRetry: (_) async => prepareCalls++,
      );

      expect(result.success, isTrue);
      expect(attempt, 1);
      expect(prepareCalls, 1);
    });

    test('fails without preparing after the last attempt', () async {
      var prepareCalls = 0;

      final result = await runAttempts(
        2,
        attemptSession: (_, __) async => false,
        prepareForRetry: (_) async => prepareCalls++,
      );

      expect(result.success, isFalse);
      expect(result.error, isNull);
      expect(prepareCalls, 1);
    });

    test('treats thrown attempt errors as failure and continues retrying',
        () async {
      var attempts = 0;

      final result = await runAttempts(
        2,
        attemptSession: (_, __) async {
          attempts++;
          if (attempts == 1) {
            throw Exception('session failed');
          }
          return true;
        },
        prepareForRetry: (_) async {},
      );

      expect(result.success, isTrue);
      expect(attempts, 2);
    });

    test('reports the most recent error as the failure cause', () async {
      final prepareError = StateError('device not advertising');
      final attemptError = Exception('no sensor data');

      final result = await runAttempts(
        2,
        attemptSession: (_, index) async {
          if (index == 1) {
            throw attemptError;
          }
          return false;
        },
        prepareForRetry: (_) async => throw prepareError,
      );

      expect(result.success, isFalse);
      expect(result.error, same(attemptError));
      expect(result.stackTrace, isNotNull);
    });

    test('keeps a prepare error as the cause when attempts fail silently',
        () async {
      final prepareError = StateError('device not advertising');

      final result = await runAttempts(
        2,
        attemptSession: (_, __) async => false,
        prepareForRetry: (_) async => throw prepareError,
      );

      expect(result.success, isFalse);
      expect(result.error, same(prepareError));
    });
  });

  group('BleSessionRetryRunner.prepareDeviceLink', () {
    test('disconnects and propagates a connect failure', () async {
      var disconnected = false;

      await expectLater(
        runner.prepareDeviceLink(
          device,
          disconnect: () async => disconnected = true,
          connect: () async => throw Exception('connect failed'),
        ),
        throwsException,
      );

      expect(disconnected, isTrue);
    });

    test('completes link preparation when connect succeeds', () async {
      var disconnected = false;
      var connectCalls = 0;

      await runner.prepareDeviceLink(
        device,
        disconnect: () async => disconnected = true,
        connect: () async => connectCalls++,
      );

      expect(disconnected, isTrue);
      expect(connectCalls, 1);
    });

    test('waits once after disconnect before connecting', () async {
      runner = BleSessionRetryRunner(
        delayBetweenSteps: const Duration(milliseconds: 100),
      );
      final stopwatch = Stopwatch()..start();
      var disconnectAt = Duration.zero;

      await runner.prepareDeviceLink(
        device,
        disconnect: () async => disconnectAt = stopwatch.elapsed,
        connect: () async {},
      );

      expect(disconnectAt, lessThan(const Duration(milliseconds: 100)));
      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 100)),
      );
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(milliseconds: 200)),
      );
    });
  });
}
