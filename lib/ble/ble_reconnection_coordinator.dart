import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:vibration/vibration.dart';

/// Watches [BluetoothDevice.connectionState] and runs reconnect attempts after
/// unexpected disconnects.
class BleReconnectionCoordinator {
  BleReconnectionCoordinator({
    required this.isReconnectingNotifier,
    required bool Function() getVibrateOnDisconnect,
  }) : _getVibrateOnDisconnect = getVibrateOnDisconnect;

  final ValueNotifier<bool> isReconnectingNotifier;
  final bool Function() _getVibrateOnDisconnect;

  StreamSubscription<BluetoothConnectionState>? _subscription;
  bool _reconnectionInProgress = false;
  int _reconnectionAttempts = 0;
  bool _hasVibrated = false;

  void recordAttempt() => _reconnectionAttempts++;

  void attach(
    BluetoothDevice device, {
    required bool Function() shouldIgnoreDisconnect,
    required void Function() onLinkLost,
    required Future<bool> Function(BluetoothDevice device) runReconnectSessions,
    required void Function() onReconnectSucceeded,
    required Future<void> Function(BluetoothDevice device, Object error)
        onListenerError,
  }) {
    detach();
    reset(keepNotifier: true);

    _subscription = device.connectionState.listen((state) async {
      try {
        if (state == BluetoothConnectionState.disconnected &&
            !shouldIgnoreDisconnect()) {
          if (!_reconnectionInProgress) {
            onLinkLost();
            try {
              await _startReconnection(
                device,
                runReconnectSessions: runReconnectSessions,
                onReconnectSucceeded: onReconnectSucceeded,
              );
            } catch (_) {
              reset();
            }
          }
        }
      } catch (_) {
        // Let the reconnection process handle errors.
      }
    });

    _subscription?.onError((error) {
      unawaited(onListenerError(device, error));
    });
  }

  Future<void> _startReconnection(
    BluetoothDevice device, {
    required Future<bool> Function(BluetoothDevice device) runReconnectSessions,
    required void Function() onReconnectSucceeded,
  }) async {
    if (_reconnectionInProgress) {
      if (_reconnectionAttempts >= bleMaxReconnectionAttempts) {
        reset();
      } else {
        return;
      }
    }

    _reconnectionInProgress = true;
    isReconnectingNotifier.value = true;

    if (!_hasVibrated && _getVibrateOnDisconnect()) {
      Vibration.vibrate();
      _hasVibrated = true;
    }

    final success = await runReconnectSessions(device);
    if (success) {
      reset();
      onReconnectSucceeded();
    }
  }

  void detach() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Clears in-progress reconnect state. [detach] cancels the connection listener.
  void reset({bool keepNotifier = false}) {
    _reconnectionInProgress = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;
    if (!keepNotifier) {
      isReconnectingNotifier.value = false;
    }
  }
}
