import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';

class BleSessionRetryRunner {
  BleSessionRetryRunner({
    this.delayBetweenSteps = bleSessionRetryDelay,
  });

  final Duration delayBetweenSteps;

  Future<bool> run({
    required BleDevice device,
    required int maxAttempts,
    required Future<bool> Function(BleDevice device, int attemptIndex)
        attemptSession,
    required Future<void> Function(BleDevice device) prepareForRetry,
    void Function()? onEnterRetryMode,
    void Function()? onExitRetryMode,
    void Function(int attemptIndex)? onBetweenAttempts,
    Future<void> Function()? onExhausted,
  }) async {
    onEnterRetryMode?.call();

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        onBetweenAttempts?.call(attempt);
      }

      try {
        var success = false;
        try {
          success = await attemptSession(device, attempt);
        } catch (_) {
          success = false;
        }

        if (success) {
          onExitRetryMode?.call();
          return true;
        }

        if (attempt < maxAttempts - 1) {
          try {
            await prepareForRetry(device);
          } catch (_) {
            // Continue with next attempt anyway.
          }
        }
      } catch (_) {
        if (attempt < maxAttempts - 1) {
          try {
            await prepareForRetry(device);
          } catch (_) {
            // Continue with next attempt anyway.
          }
        }
      }
    }

    onExitRetryMode?.call();
    if (onExhausted != null) {
      await onExhausted();
    }
    return false;
  }

  Future<void> prepareDeviceLink(
    BleDevice device, {
    required Future<void> Function() disconnect,
    required Future<void> Function() connect,
  }) async {
    try {
      await disconnect();
      if (delayBetweenSteps > Duration.zero) {
        await Future.delayed(delayBetweenSteps);
      }

      try {
        await connect();
      } catch (_) {
        return;
      }
    } catch (_) {
      // Let the retry loop continue with the next attempt.
    }
  }
}
