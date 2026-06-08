import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/utils/device_vibration.dart';

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
  bool _hasVibrated = false;
  bool _abortReconnection = false;

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
            !shouldIgnoreDisconnect() &&
            !_reconnectionInProgress) {
          onLinkLost();
          await _runReconnectionEpisode(
            device,
            runReconnectSessions: runReconnectSessions,
            onReconnectSucceeded: onReconnectSucceeded,
          );
        }
      } catch (_) {
        // Let the reconnection process handle errors.
      }
    });

    _subscription?.onError((error) {
      unawaited(onListenerError(device, error));
    });
  }

  void cancelReconnection() {
    _abortReconnection = true;
    detach();
    reset();
  }

  Future<void> _runReconnectionEpisode(
    BluetoothDevice device, {
    required Future<bool> Function(BluetoothDevice device) runReconnectSessions,
    required void Function() onReconnectSucceeded,
  }) async {
    if (_abortReconnection) {
      return;
    }

    _reconnectionInProgress = true;
    isReconnectingNotifier.value = true;

    try {
      if (_abortReconnection) {
        return;
      }
      await _maybeVibrateOnDisconnect();
      final success = await runReconnectSessions(device);
      if (success) {
        onReconnectSucceeded();
      }
    } finally {
      reset();
    }
  }

  Future<void> _maybeVibrateOnDisconnect() async {
    if (_hasVibrated || !_getVibrateOnDisconnect()) {
      return;
    }
    _hasVibrated = true;
    try {
      await vibrateDisconnectFeedback();
    } catch (_) {
      // Haptics are best-effort; reconnect must continue.
    }
  }

  void detach() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Clears in-progress reconnect state. [detach] cancels the connection listener.
  void reset({bool keepNotifier = false}) {
    _reconnectionInProgress = false;
    _hasVibrated = false;
    if (!keepNotifier) {
      isReconnectingNotifier.value = false;
    }
  }
}
