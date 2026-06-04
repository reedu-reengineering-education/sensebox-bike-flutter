import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';

class BleSessionRetryRunner {
  const BleSessionRetryRunner({
    this.delayBetweenSteps = bleSessionRetryDelay,
    this.connectTimeout = bleDeviceConnectTimeout,
  });

  final Duration delayBetweenSteps;
  final Duration connectTimeout;

  /// Runs [attemptSession] up to [maxAttempts] times, calling [prepareForRetry]
  /// between failures. Returns true when an attempt succeeds.
  Future<bool> run({
    required BluetoothDevice device,
    required int maxAttempts,
    required Future<bool> Function(BluetoothDevice device, int attemptIndex)
        attemptSession,
    required Future<void> Function(BluetoothDevice device) prepareForRetry,
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

  /// Disconnects, waits, reconnects GATT link, then waits again before the next session attempt.
  Future<void> prepareDeviceLink(
    BluetoothDevice device, {
    required Future<void> Function() disconnect,
  }) async {
    try {
      await disconnect();
      await Future.delayed(delayBetweenSteps);

      try {
        await device.connect(timeout: connectTimeout);
      } catch (_) {
        return;
      }

      await Future.delayed(delayBetweenSteps);
    } catch (_) {
      // Let the retry loop continue with the next attempt.
    }
  }
}
