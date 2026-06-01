import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/blocs/ble_connection_state.dart';
import 'package:vibration/vibration.dart';

typedef BleAttemptConnection = Future<bool> Function(
  BluetoothDevice device,
  BuildContext? context,
);

typedef BleConnectionErrorHandler = void Function({
  required BuildContext context,
  bool isInitialConnection,
});

const _defaultRetryDelay = Duration(seconds: 1);

class BleConnectionManager {
  BleConnectionManager({
    required this.deviceConnectTimeout,
    this.retryDelay = _defaultRetryDelay,
    this.maxReconnectionAttempts = 10,
  });

  final Duration deviceConnectTimeout;
  final Duration retryDelay;
  final int maxReconnectionAttempts;

  StreamSubscription<BluetoothConnectionState>? _reconnectionListener;
  bool _isInRetryMode = false;
  bool _hasVibrated = false;

  bool get isInRetryMode => _isInRetryMode;

  /// Runs [attemptConnection] up to [maxAttempts] times with BLE retry prep
  /// between attempts. Calls [handleError] if all attempts fail (when context
  /// is non-null). Calls [onRetryAttempt] before each retry.
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

  /// Starts watching for unexpected transport disconnects on [device] and
  /// automatically retries up to [maxReconnectionAttempts] times.
  void watchForDisconnect(
    BluetoothDevice device, {
    required bool Function() shouldSkipReconnect,
    required BleAttemptConnection attemptReconnection,
    required void Function() onReconnectSuccess,
    required void Function(BleConnectionState) onStateChange,
    required BleConnectionErrorHandler onPermanentFailure,
    required bool vibrateOnDisconnect,
    required BuildContext context,
  }) {
    _reconnectionListener?.cancel();
    _hasVibrated = false;

    _reconnectionListener = device.connectionState.listen((state) async {
      try {
        if (state == BluetoothConnectionState.disconnected &&
            !shouldSkipReconnect() &&
            !_isInRetryMode) {
          onStateChange(BleConnectionState.reconnecting);
          try {
            await _startReconnectionProcess(
              device,
              context,
              attemptReconnection: attemptReconnection,
              onReconnectSuccess: onReconnectSuccess,
              onStateChange: onStateChange,
              onPermanentFailure: onPermanentFailure,
              vibrateOnDisconnect: vibrateOnDisconnect,
            );
          } catch (_) {
            _isInRetryMode = false;
          }
        }
      } catch (_) {}
    });

    _reconnectionListener?.onError((_) {
      onPermanentFailure(context: context, isInitialConnection: false);
    });
  }

  /// Cancels any active reconnection listener and resets all reconnection state.
  void cancelReconnection() {
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
    _isInRetryMode = false;
    _hasVibrated = false;
  }

  void dispose() {
    cancelReconnection();
  }

  Future<void> _startReconnectionProcess(
    BluetoothDevice device,
    BuildContext context, {
    required BleAttemptConnection attemptReconnection,
    required void Function() onReconnectSuccess,
    required void Function(BleConnectionState) onStateChange,
    required BleConnectionErrorHandler onPermanentFailure,
    required bool vibrateOnDisconnect,
  }) async {
    _isInRetryMode = true;

    if (!_hasVibrated && vibrateOnDisconnect) {
      Vibration.vibrate();
      _hasVibrated = true;
    }

    final success = await _executeConnectionAttempts(
      device,
      context,
      maxAttempts: maxReconnectionAttempts,
      isReconnection: true,
      attemptConnection: (device, context) => attemptReconnection(device, context),
      handleError: onPermanentFailure,
      onRetryAttempt: () => onStateChange(BleConnectionState.reconnecting),
    );

    _isInRetryMode = false;

    if (success) {
      _hasVibrated = false;
      onReconnectSuccess();
    }
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
    } catch (_) {}
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
