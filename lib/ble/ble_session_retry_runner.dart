import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';

class BleSessionRetryRunner {
  BleSessionRetryRunner({
    required this.platform,
    this.delayBetweenSteps = bleSessionRetryDelay,
    this.connectTimeout = bleDeviceConnectTimeout,
  });

  final BlePlatform platform;
  final Duration delayBetweenSteps;
  final Duration connectTimeout;

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
  }) async {
    try {
      await disconnect();
      await Future.delayed(delayBetweenSteps);

      try {
        await platform.connect(device.id, timeout: connectTimeout);
      } catch (_) {
        return;
      }

      await Future.delayed(delayBetweenSteps);
    } catch (_) {
      // Let the retry loop continue with the next attempt.
    }
  }
}
