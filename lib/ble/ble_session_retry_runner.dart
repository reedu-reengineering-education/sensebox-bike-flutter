import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';

class BleSessionRetryResult {
  const BleSessionRetryResult.success()
      : success = true,
        error = null,
        stackTrace = null;

  const BleSessionRetryResult.failure([this.error, this.stackTrace])
      : success = false;

  final bool success;
  final Object? error;
  final StackTrace? stackTrace;
}

class BleSessionRetryRunner {
  BleSessionRetryRunner({
    this.delayBetweenSteps = bleSessionRetryDelay,
  });

  final Duration delayBetweenSteps;

  Future<BleSessionRetryResult> run({
    required BleDevice device,
    required Duration timeLimit,
    required bool Function() shouldStop,
    required Future<bool> Function(BleDevice device, int attemptIndex)
        attemptSession,
    required Future<void> Function(BleDevice device) prepareForRetry,
  }) async {
    final elapsed = Stopwatch()..start();
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; !shouldStop(); attempt++) {
      try {
        if (await attemptSession(device, attempt)) {
          return const BleSessionRetryResult.success();
        }
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }

      if (elapsed.elapsed >= timeLimit || shouldStop()) {
        break;
      }

      try {
        await prepareForRetry(device);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    return BleSessionRetryResult.failure(lastError, lastStackTrace);
  }

  Future<void> prepareDeviceLink(
    BleDevice device, {
    required Future<void> Function() disconnect,
    required Future<void> Function() connect,
  }) async {
    await disconnect();
    if (delayBetweenSteps > Duration.zero) {
      await Future.delayed(delayBetweenSteps);
    }
    await connect();
  }
}
