import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

typedef BleAttemptConnection = Future<bool> Function(
  BluetoothDevice device,
  BuildContext? context,
);

typedef BleConnectionErrorHandler = void Function({
  required BuildContext context,
  bool isInitialConnection,
});

class BleConnectionManager {
  BleConnectionManager({
    required this.deviceConnectTimeout,
    required this.retryDelay,
  });

  final Duration deviceConnectTimeout;
  final Duration retryDelay;

  Future<bool> attemptConnectionWithRetries(
    BluetoothDevice device, {
    BuildContext? context,
    int maxAttempts = 5,
    bool isReconnection = false,
    required BleAttemptConnection attemptConnection,
    required BleConnectionErrorHandler handleError,
    required VoidCallback onRetryAttempt,
  }) {
    assert(maxAttempts > 0, 'maxAttempts must be greater than 0');

    return _executeConnectionAttempts(
      device,
      context,
      maxAttempts: maxAttempts,
      isReconnection: isReconnection,
      attemptConnection: attemptConnection,
      handleError: handleError,
      onRetryAttempt: onRetryAttempt,
    );
  }

  Future<bool> _executeConnectionAttempts(
    BluetoothDevice device,
    BuildContext? context, {
    required int maxAttempts,
    required bool isReconnection,
    required BleAttemptConnection attemptConnection,
    required BleConnectionErrorHandler handleError,
    required VoidCallback onRetryAttempt,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final success = await _attemptOnce(device, context, attemptConnection);
      if (success) {
        return true;
      }

      final hasRemainingAttempts = attempt < maxAttempts - 1;
      if (hasRemainingAttempts) {
        onRetryAttempt();
        await _prepareForRetry(device);
      }
    }

    if (context != null) {
      handleError(context: context, isInitialConnection: !isReconnection);
    }
    return false;
  }

  Future<bool> _attemptOnce(
    BluetoothDevice device,
    BuildContext? context,
    BleAttemptConnection attemptConnection,
  ) async {
    try {
      return await attemptConnection(device, context);
    } catch (_) {
      return false;
    }
  }

  Future<void> _prepareForRetry(BluetoothDevice device) async {
    await _safeDisconnect(device);
    await Future.delayed(retryDelay);

    final reconnected = await _safeReconnect(device);
    if (reconnected) {
      await Future.delayed(retryDelay);
    }
  }

  Future<void> _safeDisconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {
      // Device might already be disconnected.
    }
  }

  Future<bool> _safeReconnect(BluetoothDevice device) async {
    try {
      await device.connect(timeout: deviceConnectTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }
}
