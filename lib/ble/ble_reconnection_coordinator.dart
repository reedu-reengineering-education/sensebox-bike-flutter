import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/utils/device_vibration.dart';

/// Watches connection state and runs reconnect attempts after unexpected disconnects.
class BleReconnectionCoordinator {
  BleReconnectionCoordinator({
    required this.platform,
    required this.isReconnectingNotifier,
    required bool Function() getVibrateOnDisconnect,
  }) : _getVibrateOnDisconnect = getVibrateOnDisconnect;

  final BlePlatform platform;
  final ValueNotifier<bool> isReconnectingNotifier;
  final bool Function() _getVibrateOnDisconnect;

  StreamSubscription<BleLinkState>? _subscription;
  bool _reconnectionInProgress = false;
  bool _hasVibrated = false;
  bool _abortReconnection = false;

  void attach(
    BleDevice device, {
    required bool Function() shouldIgnoreDisconnect,
    required void Function() onLinkLost,
    required Future<bool> Function(BleDevice device) runReconnectSessions,
    required void Function() onReconnectSucceeded,
    required Future<void> Function(BleDevice device, Object error)
        onListenerError,
  }) {
    detach();
    reset(keepNotifier: true);
    _abortReconnection = false;

    _subscription = platform.connectionState(device.id).listen((state) async {
      try {
        if (state == BleLinkState.disconnected &&
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
    BleDevice device, {
    required Future<bool> Function(BleDevice device) runReconnectSessions,
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

  void reset({bool keepNotifier = false}) {
    _reconnectionInProgress = false;
    _hasVibrated = false;
    if (!keepNotifier) {
      isReconnectingNotifier.value = false;
    }
  }
}
